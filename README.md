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

- Default quant preset: `Balanced`
- Default suggested file: `qwen2.5-0.5b-instruct-q4_k_m.gguf`
- Runtime: `llama-completion`
- Inference mode: offline after first cache download

TextKit also includes an experimental larger-model option:

- Stable: `Qwen2.5 0.5B`
- Experimental: `Qwen3.5 0.8B (Experimental)`

The app invokes `llama-completion` directly and uses the standard Hugging Face cache populated by `llama.cpp`.

## Setup the local model

```bash
./script/setup_model_runtime.sh
```

That command:

- installs `llama.cpp` with Homebrew if needed
- caches the default balanced quant for `Qwen/Qwen2.5-0.5B-Instruct-GGUF`
- runs a one-shot smoke test

To cache a different quant explicitly:

```bash
./script/setup_model_runtime.sh --quant quality
```

To cache the experimental model instead:

```bash
./script/setup_model_runtime.sh --model experimental --quant balanced
```

After setup, the app uses `--offline` so normal inference does not depend on network access.

## Advanced prompt controls

Settings now includes an advanced profile editor for every tool mode:

- locked base system prompt
- editable mode-specific system instruction
- editable task template
- per-mode temperature, max tokens, and seed
- strict mode toggle for more repeatable output
- prompt preview with sample input
- reset, import, and export actions for prompt profiles

The input and output panes in the popover also resize dynamically based on the current clipboard text and generated response.

## Build

```bash
./script/build_and_run.sh
```

Use `./script/build_and_run.sh --verify` for a build plus launch check.

## Verify the model

```bash
./script/setup_model_runtime.sh --smoke-test
```

## Golden eval harness

The repo now includes a rewrite-focused golden eval harness so prompt changes and future model swaps can be measured against the same cases.

Run the full rewrite suite:

```bash
./script/run_golden_eval.sh
```

Run one mode or a narrow case slice while tuning:

```bash
./script/run_golden_eval.sh --mode rewrite.short
./script/run_golden_eval.sh --case board-update
```

By default the harness uses the repo prompt defaults with deterministic strict-style sampling for repeatability. To compare raw defaults instead:

```bash
./script/run_golden_eval.sh --defaults
```

The default threshold expects the selected cases to pass, so a failing run is the signal to tune prompts, post-processing, or model choice before changing the baseline.

To compare the experimental model against the same golden rewrite set:

```bash
./script/run_golden_eval.sh --model experimental
```

## Release notes

Git is initialized from the start so we can commit incrementally as the app evolves. Homebrew tap/cask work is intentionally deferred until there is a signed, working release artifact worth publishing.
