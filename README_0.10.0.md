This branch is a work in progress, currently aimed at replicating a cosmopolitan
llama.cpp build from scratch.

For this reason, the regular llamafile build will likely fail for a while. The most
up-to-date instructions on how to replicate our builds are here.

# Building llamafile v0.10.0

The code currently contains the minimum set of changes required to rebuild llama.cpp
with cosmopolitan. It is based on llama.cpp commit dbc15a79672e72e0b9c1832adddf3334f5c9229c
(Dec, 6, 2025).

Run `make setup` to pull from the git submodules and apply the required patches.
Then, run the following to build the llamafile APE:

```
make -j8
```

> [!NOTE]
> If you get the "please use bin/make from cosmocc.zip rather than old xcode make" message
> (likely to happen on a Mac), run the following to download cosmocc into the `.cosmocc/4.0.2`
> directory:
>
> ```
> build/download-cosmocc.sh .cosmocc/4.0.2 4.0.2 85b8c37a406d862e656ad4ec14be9f6ce474c1b436b9615e91a55208aced3f44
> ```
>
> You can then either add the cosmocc binaries dir to your path or directly run:
>
> ```
> .cosmocc/4.0.2/bin/make -j8
> ```

You can then run the llamafile TUI as

```
./o/llamafile/llamafile --model <gguf_model>
```

or the llama.cpp server as

```
./o/llamafile/llamafile --model <gguf_model> --server
```

> [!NOTE]
> If you want, you can still build the vanilla llama.cpp server with:
> 
> ```
> make -j8 o//llama.cpp/server/llama-server
> ```

# What's new

20251215
- added TUI support: you can now directly chat with the chosen LLM from
the terminal, or run the llama.cpp server using the `--server` parameter
- simplified build by removing all tools/deps except those required by
the new llamafile code (they will be added back in as soon as we reintroduce
functionalities)

20251209
- added BUILD.mk so we can do without cmake
- build works with cosmocc 4.0.2
- dependencies are all taken from llama.cpp/vendor directory
- building now works both on linux and mac

20251208
- updated to llama.cpp commit dbc15a79672e72e0b9c1832adddf3334f5c9229c

20251124
- first version, relying on cmake for the build

