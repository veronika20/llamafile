#-*-mode:makefile-gmake;indent-tabs-mode:t;tab-width:8;coding:utf-8-*-┐
#── vi: set noet ft=make ts=8 sw=8 fenc=utf-8 :vi ────────────────────┘

PKGS += LLAMAFILE

# ==============================================================================
# Version information
# ==============================================================================

LLAMAFILE_VERSION_STRING := 0.10.0-dev

# ==============================================================================
# Include paths
# ==============================================================================

LLAMAFILE_INCLUDES := \
	-iquote llamafile \
	-iquote llama.cpp/common \
	-iquote llama.cpp/include \
	-iquote llama.cpp/ggml/include \
	-iquote llama.cpp/ggml/src \
	-iquote llama.cpp/ggml/src/ggml-cpu \
	-iquote llama.cpp/src \
	-iquote llama.cpp/tools/mtmd \
	-isystem llama.cpp/vendor \
	-isystem third_party

# ==============================================================================
# Compiler flags
# ==============================================================================

LLAMAFILE_CPPFLAGS := \
	$(LLAMAFILE_INCLUDES) \
	-DLLAMAFILE_VERSION_STRING=\"$(LLAMAFILE_VERSION_STRING)\" \
    -DCOSMOCC=1

# ==============================================================================
# Source files - Highlight library
# ==============================================================================

LLAMAFILE_HIGHLIGHT_SRCS := \
	llamafile/highlight/color_bleeder.cpp \
	llamafile/highlight/highlight.cpp \
	llamafile/highlight/highlight_ada.cpp \
	llamafile/highlight/highlight_asm.cpp \
	llamafile/highlight/highlight_basic.cpp \
	llamafile/highlight/highlight_bnf.cpp \
	llamafile/highlight/highlight_c.cpp \
	llamafile/highlight/highlight_cmake.cpp \
	llamafile/highlight/highlight_cobol.cpp \
	llamafile/highlight/highlight_csharp.cpp \
	llamafile/highlight/highlight_css.cpp \
	llamafile/highlight/highlight_d.cpp \
	llamafile/highlight/highlight_forth.cpp \
	llamafile/highlight/highlight_fortran.cpp \
	llamafile/highlight/highlight_go.cpp \
	llamafile/highlight/highlight_haskell.cpp \
	llamafile/highlight/highlight_html.cpp \
	llamafile/highlight/highlight_java.cpp \
	llamafile/highlight/highlight_js.cpp \
	llamafile/highlight/highlight_julia.cpp \
	llamafile/highlight/highlight_kotlin.cpp \
	llamafile/highlight/highlight_ld.cpp \
	llamafile/highlight/highlight_lisp.cpp \
	llamafile/highlight/highlight_lua.cpp \
	llamafile/highlight/highlight_m4.cpp \
	llamafile/highlight/highlight_make.cpp \
	llamafile/highlight/highlight_markdown.cpp \
	llamafile/highlight/highlight_matlab.cpp \
	llamafile/highlight/highlight_ocaml.cpp \
	llamafile/highlight/highlight_pascal.cpp \
	llamafile/highlight/highlight_perl.cpp \
	llamafile/highlight/highlight_php.cpp \
	llamafile/highlight/highlight_python.cpp \
	llamafile/highlight/highlight_r.cpp \
	llamafile/highlight/highlight_ruby.cpp \
	llamafile/highlight/highlight_rust.cpp \
	llamafile/highlight/highlight_scala.cpp \
	llamafile/highlight/highlight_shell.cpp \
	llamafile/highlight/highlight_sql.cpp \
	llamafile/highlight/highlight_swift.cpp \
	llamafile/highlight/highlight_tcl.cpp \
	llamafile/highlight/highlight_tex.cpp \
	llamafile/highlight/highlight_txt.cpp \
	llamafile/highlight/highlight_typescript.cpp \
	llamafile/highlight/highlight_zig.cpp \
	llamafile/highlight/util.cpp

# ==============================================================================
# Source files - Core TUI
# ==============================================================================

LLAMAFILE_SRCS_C := \
	llamafile/bestline.c \
	llamafile/llamafile.c \
	llamafile/zip.c

LLAMAFILE_SRCS_CPP := \
	llamafile/chatbot_comm.cpp \
	llamafile/chatbot_comp.cpp \
	llamafile/chatbot_eval.cpp \
	llamafile/chatbot_file.cpp \
	llamafile/chatbot_help.cpp \
	llamafile/chatbot_hint.cpp \
	llamafile/chatbot_hist.cpp \
	llamafile/chatbot_logo.cpp \
	llamafile/chatbot_main.cpp \
	llamafile/chatbot_repl.cpp \
	llamafile/compute.cpp \
	llamafile/datauri.cpp \
	llamafile/image.cpp \
	llamafile/llama.cpp \
	llamafile/string.cpp \
	llamafile/xterm.cpp \
	$(LLAMAFILE_HIGHLIGHT_SRCS)

# ==============================================================================
# Object files
# ==============================================================================

LLAMAFILE_OBJS := \
	$(LLAMAFILE_SRCS_C:%.c=o/$(MODE)/%.o) \
	$(LLAMAFILE_SRCS_CPP:%.cpp=o/$(MODE)/%.o)

# ==============================================================================
# Dependency libraries
# ==============================================================================

# Dependencies from llama.cpp/BUILD.mk:
#   GGML_OBJS   - Core tensor operations
#   LLAMA_OBJS  - LLM inference
#   COMMON_OBJS - Common utilities (arg parsing, sampling, chat templates)
#   MTMD_OBJS   - Multimodal support (vision models)
#   HTTPLIB_OBJS - HTTP client support for downloads
# Dependencies from llamafile/highlight/BUILD.mk:
#   We only need the gperf-generated keyword dictionary objects, not the
#   highlight cpp files (since we have our own copies in llamafile/highlight)

LLAMAFILE_HIGHLIGHT_GPERF_FILES := $(wildcard llamafile/highlight/*.gperf)
LLAMAFILE_HIGHLIGHT_KEYWORDS := $(LLAMAFILE_HIGHLIGHT_GPERF_FILES:%.gperf=o/$(MODE)/%.o)

# Server objects for llamafile (compiled with -DLLAMAFILE_TUI to exclude standalone main)
# Note: server.cpp is compiled separately below with LLAMAFILE_TUI defined
LLAMAFILE_SERVER_SUPPORT_OBJS := \
	o/$(MODE)/llama.cpp/tools/server/server-common.cpp.o \
	o/$(MODE)/llama.cpp/tools/server/server-context.cpp.o \
	o/$(MODE)/llama.cpp/tools/server/server-http.cpp.o \
	o/$(MODE)/llama.cpp/tools/server/server-models.cpp.o \
	o/$(MODE)/llama.cpp/tools/server/server-queue.cpp.o \
	o/$(MODE)/llama.cpp/tools/server/server-task.cpp.o

LLAMAFILE_DEPS := \
	$(GGML_OBJS) \
	$(LLAMA_OBJS) \
	$(COMMON_OBJS) \
	$(MTMD_OBJS) \
	$(HTTPLIB_OBJS) \
	$(LLAMAFILE_SERVER_SUPPORT_OBJS) \
	$(LLAMAFILE_HIGHLIGHT_KEYWORDS) \
	o/$(MODE)/third_party/stb/stb_image_resize2.o

# ==============================================================================
# Server integration
# ==============================================================================

# Include paths needed for server compilation
LLAMAFILE_SERVER_INCS := \
	$(LLAMAFILE_INCLUDES) \
	-iquote llama.cpp/tools/server \
	-iquote o/$(MODE)/llama.cpp/tools/server

# Compile server.cpp with -DLLAMAFILE_TUI to exclude standalone main()
o/$(MODE)/llamafile/server.cpp.o: llama.cpp/tools/server/server.cpp $(SERVER_ASSETS)
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(LLAMAFILE_CPPFLAGS) $(LLAMAFILE_SERVER_INCS) -DLLAMAFILE_TUI -c -o $@ $<

# ==============================================================================
# Main executable
# ==============================================================================

o/$(MODE)/llamafile/main.o: llamafile/main.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(LLAMAFILE_CPPFLAGS) -c -o $@ $<

o/$(MODE)/llamafile/llamafile: \
		o/$(MODE)/llamafile/main.o \
		o/$(MODE)/llamafile/server.cpp.o \
		$(LLAMAFILE_OBJS) \
		$(LLAMAFILE_DEPS) \
		$(SERVER_ASSETS)
	@mkdir -p $(@D)
	$(CXX) $(LDFLAGS) -o $@ $(filter %.o,$^) $(LDLIBS)

# ==============================================================================
# Pattern rules for llamafile sources
# ==============================================================================

o/$(MODE)/llamafile/%.o: llamafile/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $(LLAMAFILE_INCLUDES) -c -o $@ $<

o/$(MODE)/llamafile/%.o: llamafile/%.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(LLAMAFILE_CPPFLAGS) -c -o $@ $<

o/$(MODE)/llamafile/highlight/%.o: llamafile/highlight/%.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) $(LLAMAFILE_CPPFLAGS) -c -o $@ $<

# ==============================================================================
# Targets
# ==============================================================================

.PHONY: o/$(MODE)/llamafile
o/$(MODE)/llamafile: o/$(MODE)/llamafile/llamafile
