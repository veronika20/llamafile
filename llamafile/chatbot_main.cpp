// -*- mode:c++;indent-tabs-mode:nil;c-basic-offset:4;coding:utf-8 -*-
// vi: set et ft=cpp ts=4 sts=4 sw=4 fenc=utf-8 :vi
//
// Copyright 2024 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "chatbot.h"

#include <cosmo.h>
#include <cstdio>
#include <signal.h>
#include <string>
#include <vector>

#include "arg.h"
#include "common.h"
#include "llama.h"
#include "log.h"
#include "sampling.h"
#include "mtmd.h"

#include "color.h"
#include "compute.h"
#include "llama.h"  // llamafile wrapper
#include "string.h"
#include "llamafile.h"

// Version string - should be defined by build system
#ifndef LLAMAFILE_VERSION_STRING
#define LLAMAFILE_VERSION_STRING "0.10.0-dev"
#endif

// Null log callback to suppress llama.cpp logging
static void llama_log_callback_null(ggml_log_level level, const char *text, void *user_data) {
    (void)level;
    (void)text;
    (void)user_data;
}

namespace lf {
namespace chatbot {

// Global state
common_params *g_params = nullptr;      // pointer to params
common_sampler *g_sampler = nullptr;    // sampler context
mtmd_context *g_mtmd = nullptr;         // multimodal context
llama_model *g_model = nullptr;
llama_context *g_ctx = nullptr;

// Static storage for params
static common_params s_params;

std::string describe_compute(void) {
    // Check if using GPU based on params
    if (g_params && g_params->n_gpu_layers > 0 && llamafile_has_gpu()) {
        if (llamafile_has_metal()) {
            return "Apple Metal GPU";
        } else {
            // Try to get CUDA device info if available
            return llamafile_describe_cpu() + " (with GPU acceleration)";
        }
    } else {
        return llamafile_describe_cpu();
    }
}

std::string token_to_piece(const struct llama_context *ctx, llama_token token, bool special) {
    if (token == IMAGE_PLACEHOLDER_TOKEN)
        return "⁑";
    return llamafile_token_to_piece(ctx, token, special);
}

const char *tip() {
    if (g_params->verbosity)
        return "";
    return " (use the --verbose flag for further details)";
}

bool is_base_model() {
    // check if user explicitly passed --chat-template flag
    if (!g_params->chat_template.empty())
        return false;

    // check if gguf metadata has chat template. this should always be
    // present for "instruct" models, and never specified on base ones
    return llama_model_meta_val_str(g_model, "tokenizer.chat_template", 0, 0) == -1;
}

int main(int argc, char **argv) {
    signal(SIGPIPE, SIG_IGN);

    // print logo
    logo(argv);

    // Check if verbose mode is requested
    bool verbose = llamafile_has(argv, "--verbose");

    // Initialize params with defaults
    g_params = &s_params;
    g_params->sampling.n_prev = 64;
    g_params->n_batch = 256;  // for better progress indication
    g_params->sampling.temp = 0;  // don't use randomness by default
    g_params->prompt = DEFAULT_SYSTEM_PROMPT;

    // parse flags
    print_ephemeral("loading backend...");
    llama_backend_init();
    common_init();

    if (!common_params_parse(argc, argv, *g_params, LLAMA_EXAMPLE_MAIN)) {
        fprintf(stderr, "error: failed to parse flags\n");
        exit(1);
    }
    clear_ephemeral();

    // Suppress logging for model loading unless --verbose was specified
    // We must set this AFTER common_init() since it overwrites the log callback
    // and BEFORE model loading to suppress those logs
    if (!verbose) {
        llama_log_set(llama_log_callback_null, NULL);
    }

    print_ephemeral("loading model...");
    llama_model_params model_params = common_model_params_to_llama(*g_params);
    g_model = llama_model_load_from_file(g_params->model.path.c_str(), model_params);
    clear_ephemeral();
    if (g_model == NULL) {
        fprintf(stderr, "%s: failed to load model%s\n", g_params->model.path.c_str(), tip());
        exit(2);
    }

    // Adjust context size
    if (g_params->n_ctx <= 0 || g_params->n_ctx > (int)llama_model_n_ctx_train(g_model))
        g_params->n_ctx = llama_model_n_ctx_train(g_model);
    if (g_params->n_ctx < g_params->n_batch)
        g_params->n_batch = g_params->n_ctx;

    // Print info
    if (!FLAG_nologo) {
        printf(BOLD "software" UNBOLD ": llamafile " LLAMAFILE_VERSION_STRING "\n"
               BOLD "model" UNBOLD ":    %s\n",
               basename(g_params->model.path).c_str());
        if (is_base_model())
            printf(BOLD "mode" UNBOLD ":     RAW TEXT COMPLETION (base model)\n");
        printf(BOLD "compute" UNBOLD ":  %s\n", describe_compute().c_str());
        printf("\n");
    }

    print_ephemeral("initializing context...");
    llama_context_params ctx_params = common_context_params_to_llama(*g_params);
    g_ctx = llama_init_from_model(g_model, ctx_params);
    clear_ephemeral();
    if (!g_ctx) {
        fprintf(stderr, "error: failed to initialize context%s\n", tip());
        exit(3);
    }

    if (llama_model_has_encoder(g_model))
        fprintf(stderr, "warning: this model has an encoder\n");

    // Initialize sampler
    g_sampler = common_sampler_init(g_model, g_params->sampling);
    if (!g_sampler) {
        fprintf(stderr, "error: failed to initialize sampler\n");
        exit(4);
    }

    // Initialize multimodal if mmproj is specified
    if (!g_params->mmproj.path.empty()) {
        print_ephemeral("initializing vision model...");
        mtmd_context_params mparams = mtmd_context_params_default();
        mparams.use_gpu = g_params->mmproj_use_gpu;
        mparams.n_threads = g_params->cpuparams.n_threads;
        mparams.print_timings = g_params->verbosity > 0;
        g_mtmd = mtmd_init_from_file(g_params->mmproj.path.c_str(), g_model, mparams);
        clear_ephemeral();
        if (!g_mtmd) {
            fprintf(stderr, "%s: failed to initialize multimodal model%s\n",
                    g_params->mmproj.path.c_str(), tip());
            exit(5);
        }
    }

    // Run the REPL
    repl();

    // Cleanup
    if (g_mtmd) {
        print_ephemeral("freeing vision model...");
        mtmd_free(g_mtmd);
        clear_ephemeral();
    }

    if (g_sampler) {
        common_sampler_free(g_sampler);
    }

    print_ephemeral("freeing context...");
    llama_free(g_ctx);
    clear_ephemeral();

    print_ephemeral("freeing model...");
    llama_model_free(g_model);
    clear_ephemeral();

    print_ephemeral("freeing backend...");
    llama_backend_free();
    clear_ephemeral();

    return 0;
}

} // namespace chatbot
} // namespace lf
