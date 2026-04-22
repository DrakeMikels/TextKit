# TextKit

TextKit is a macOS menu bar utility for clipboard-first text transformation. This repo now contains the phase-1 foundation scaffold from `textkit_prd_build_sheet.md`: menu bar shell, clipboard watcher, tool/mode switching, settings persistence, and stub local generation.

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

The current default model target is the official Hugging Face repo `Qwen/Qwen2.5-0.5B-Instruct-GGUF`.

- Default suggested file: `qwen2.5-0.5b-instruct-q5_k_m.gguf`
- Planned runtime: llama.cpp-compatible GGUF backend
- Current app scaffold uses stub generation until runtime integration lands

This keeps the repo aligned with an upstream GGUF source instead of inventing custom quant names before benchmarking.

## Build

```bash
./script/build_and_run.sh
```

Use `./script/build_and_run.sh --verify` for a build plus launch check.

## Release notes

Git is initialized from the start so we can commit incrementally as the app evolves. Homebrew tap/cask work is intentionally deferred until there is a signed, working release artifact worth publishing.
