# TextKit

TextKit is a native macOS menu bar utility for clipboard-first text work. Copy text anywhere on macOS, open TextKit from the menu bar, then rewrite, summarize, extract, reply, prompt, or reduce the copied text locally.

The app is built for a frictionless non-technical install path: packaged builds bundle the local `llama.cpp` runtime, prompt users through first-run model setup, and run inference on-device after the selected model has been downloaded.

## Current Product

- Menu bar app with an icon-only status item and SwiftUI popover.
- Six top-level tools: Rewrite, Prompt, Extract, Reply, Summarize, and Reduce.
- Four modes per tool, including Clean, Short, Professional, Bullet, Brief, Executive, Logs, Structured, and related task-specific modes.
- Automatic clipboard intake with safeguards for app-authored clipboard copies.
- Manual Reduce flow for long text, logs, traces, and structured blobs.
- Local model setup UI with progress, model status, and retry support.
- Advanced prompt profile editor with preview, reset, import/export, strict mode, temperature, max tokens, and seed controls.
- Settings controls for warm runtime behavior, downloaded model cleanup, app data reset, and uninstall.

## Local AI

TextKit currently supports two local model options:

- Stable: `Qwen/Qwen2.5-0.5B-Instruct-GGUF`
- Experimental: `AaryanK/Qwen3.5-0.8B-GGUF`

The app installs one balanced GGUF file per selected model for the user-facing setup flow. The Response Mode setting changes generation behavior, not the downloaded model file:

- Fast: shorter results and lower effective token budget.
- Balanced: default for everyday clipboard work.
- Quality: allows more detail and a larger effective token budget.

When warm cache is enabled, TextKit prefers a local `llama-server` worker and shuts it down after the configured idle window. If the warm worker is unavailable or disabled, TextKit falls back to one-shot `llama-completion`.

Reduce is intentionally local-rule based and does not require the model.

## Privacy Model

TextKit has no cloud inference path. Copied text is processed locally by the app and the bundled local runtime. Network access is only needed to download a selected model during setup.

## User Install Flow

For prerelease or release builds:

1. Open the DMG or ZIP-provided app.
2. Move `TextKit.app` into Applications.
3. Open TextKit from Applications.
4. On first run, choose a model in the setup flow.
5. Download the model once, then use TextKit offline for normal text operations.

Packaged builds do not require Homebrew on the user's Mac.

## Development Requirements

TextKit is a Swift Package macOS app.

- macOS 26 target
- Xcode 26 toolchain
- Swift 6.3 package manifest
- Full Xcode install expected at `/Volumes/SSD/Applications/Xcode.app/Contents/Developer` for the local scripts in this workspace

Build and launch the local app:

```bash
./script/build_and_run.sh
```

Run tests:

```bash
xcrun swift test
```

The local build script stages the app at:

```text
dist/TextKit.app
```

## Developer Model Setup

The developer setup script uses Homebrew `llama.cpp` to populate a local model cache for development:

```bash
./script/setup_model_runtime.sh
```

Install the experimental model for local testing:

```bash
./script/setup_model_runtime.sh --model experimental --quant balanced
```

Run a model smoke test:

```bash
./script/setup_model_runtime.sh --smoke-test
```

End-user release builds should use the bundled runtime path instead of requiring Homebrew.

## Golden Eval Harness

TextKit includes a golden eval harness for rewrite behavior with tuned development cases and separate holdout cases.

Run the default dev suite:

```bash
./script/run_golden_eval.sh
```

Run the holdout suite:

```bash
./script/run_golden_eval.sh --suite holdout
```

Run a single mode or case:

```bash
./script/run_golden_eval.sh --mode rewrite.short
./script/run_golden_eval.sh --case board-update
```

Compare the experimental model against the same suite:

```bash
./script/run_golden_eval.sh --model experimental
./script/run_golden_eval.sh --model experimental --suite holdout
```

Measure the rewrite shaping layer by ablating rewrite heuristics:

```bash
./script/run_golden_eval.sh --suite holdout --ablation rewriteHeuristics --threshold 0.0
```

## Packaging

Build a local prerelease package:

```bash
./script/package_release.sh --version 0.1.0
```

The release script:

- builds the release app
- bundles the local `llama.cpp` runtime
- packages ZIP and DMG artifacts
- supports optional Developer ID signing and notarization when Apple credentials are provided through environment variables

Generated artifacts are written under:

```text
dist/release/
```

See `docs/distribution.md` for GitHub Actions, signing/notarization secrets, release artifacts, and Homebrew tap publishing.

## Repository Layout

- `Sources/App`: app entrypoint and menu bar delegate
- `Sources/Views`: popover, setup, and settings UI
- `Sources/Models`: tools, modes, model options, and request types
- `Sources/Stores`: app state, settings, and output cache
- `Sources/Services`: clipboard monitor, routing, prompt composition, inference, setup, reduction, and eval support
- `Sources/Support`: runtime lookup, cleanup, process runner, icons, and window helpers
- `Tests/TextKitTests`: unit tests, golden eval tests, and fixtures
- `script`: build, setup, eval, packaging, and runtime bundling scripts
- `Resources`: app icon resources

## License

TextKit is distributed under the AGPL-3.0 license. See `LICENSE`.
