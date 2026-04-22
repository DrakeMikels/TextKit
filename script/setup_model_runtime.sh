#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-setup}"
LLAMA_BIN="/opt/homebrew/bin/llama-completion"
PROBE_BIN="/opt/homebrew/bin/llama-cli"
MODEL_REPO="Qwen/Qwen2.5-0.5B-Instruct-GGUF"
MODEL_FILE="qwen2.5-0.5b-instruct-q5_k_m.gguf"
SYSTEM_PROMPT="You are a helpful assistant."
SMOKE_PROMPT="Reply with only the word OK."

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required to install llama.cpp." >&2
  exit 1
fi

if [[ ! -x "$LLAMA_BIN" ]] || [[ ! -x "$PROBE_BIN" ]]; then
  brew install llama.cpp
fi

model_cached() {
  "$PROBE_BIN" --cache-list 2>/dev/null | grep -q "$MODEL_REPO:Q5_K_M"
}

download_model() {
  echo "Caching $MODEL_REPO ($MODEL_FILE)..."
  "$LLAMA_BIN" \
    --verbosity 0 \
    --simple-io \
    --no-warmup \
    -hf "$MODEL_REPO" \
    -hff "$MODEL_FILE" \
    -sys "$SYSTEM_PROMPT" \
    -p "$SMOKE_PROMPT" \
    -n 8 \
    --temp 0 \
    >/dev/null
}

smoke_test() {
  "$LLAMA_BIN" \
    --verbosity 0 \
    --offline \
    --simple-io \
    --no-warmup \
    -hf "$MODEL_REPO" \
    -hff "$MODEL_FILE" \
    -sys "$SYSTEM_PROMPT" \
    -p "$SMOKE_PROMPT" \
    -n 8 \
    --temp 0
}

case "$MODE" in
  setup)
    if ! model_cached; then
      download_model
    fi
    smoke_test
    ;;
  --smoke-test|smoke-test)
    if ! model_cached; then
      echo "Model is not cached yet. Run ./script/setup_model_runtime.sh first." >&2
      exit 1
    fi
    smoke_test
    ;;
  *)
    echo "usage: $0 [setup|--smoke-test]" >&2
    exit 2
    ;;
esac
