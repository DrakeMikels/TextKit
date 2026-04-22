# TextKit

TextKit is a macOS menu bar utility for clipboard-first text transformation. The app now runs real local inference through `llama.cpp` with the official Qwen GGUF, while keeping the original menu bar shell, clipboard watcher, tool and mode switching, and settings scaffold.

## Toolchain baseline

- Xcode 26.4.1
- macOS 26.4 SDK
- Swift 6.3
- Package manifest pinned to macOS 26.0

The workspace currently has Command Line Tools selected globally, so the local run path forces `DEVELOPER_DIR=/Volumes/SSD/Applications/Xcode.app/Contents/Developer` to keep builds on the full Xcode 26 toolchain.

## Project shape

- `Sources/App`: app entrypoint
- `Sources/Views`: menu bar UI and settings surfaces
- `Sources/Models`: tool, mode, and request models
- `Sources/Stores`: app state, settings, and cache
- `Sources/Services`: clipboard monitoring, routing, prompt composition, inference stub, and model metadata
- `Tests/TextKitTests`: routing and prompt composition tests
- `script/build_and_run.sh`: kill, build, stage, and launch entrypoint

## Model plan

The current default model target is the official Hugging Face repo `Qwen/Qwen2.5-0.5B-Instruct-GGUF`, executed through Homebrew's `llama.cpp` tools.

- Default suggested file: `qwen2.5-0.5b-instruct-q5_k_m.gguf`
- Runtime: `llama-completion`
- Inference mode: offline after first cache download

The app invokes `llama-completion` directly and uses the standard Hugging Face cache populated by `llama.cpp`.

## Setup the local model

```bash
./script/setup_model_runtime.sh
```

That command:

- installs `llama.cpp` with Homebrew if needed
- caches `Qwen/Qwen2.5-0.5B-Instruct-GGUF`
- runs a one-shot smoke test

After setup, the app uses `--offline` so normal inference does not depend on network access.

## Build

```bash
./script/build_and_run.sh
```

Use `./script/build_and_run.sh --verify` for a build plus launch check.

## Verify the model

```bash
./script/setup_model_runtime.sh --smoke-test
```

## Release notes

Git is initialized from the start so we can commit incrementally as the app evolves. Homebrew tap/cask work is intentionally deferred until there is a signed, working release artifact worth publishing.
