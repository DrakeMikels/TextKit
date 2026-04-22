#!/usr/bin/env bash
set -euo pipefail

XCODE_DEVELOPER_DIR="/Volumes/SSD/Applications/Xcode.app/Contents/Developer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODEL_OPTION="stable"
QUANT_PRESET="balanced"
MODEL_PROFILE="balanced"
MIN_PASS_RATE="1.0"
SUITE="dev"
ABLATION="none"
MODE_FILTER=""
CASE_FILTER=""
USE_STRICT_PROFILE="1"

if [[ -d "$XCODE_DEVELOPER_DIR" ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-$XCODE_DEVELOPER_DIR}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL_OPTION="${2:-}"
      shift 2
      ;;
    --quant)
      QUANT_PRESET="${2:-}"
      shift 2
      ;;
    --profile)
      MODEL_PROFILE="${2:-}"
      shift 2
      ;;
    --threshold)
      MIN_PASS_RATE="${2:-}"
      shift 2
      ;;
    --suite)
      SUITE="${2:-}"
      shift 2
      ;;
    --ablation)
      ABLATION="${2:-}"
      shift 2
      ;;
    --mode)
      MODE_FILTER="${2:-}"
      shift 2
      ;;
    --case)
      CASE_FILTER="${2:-}"
      shift 2
      ;;
    --defaults)
      USE_STRICT_PROFILE="0"
      shift
      ;;
    *)
      echo "usage: $0 [--model stable|experimental] [--quant fast|balanced|quality] [--profile fast|balanced|quality] [--suite dev|holdout|all] [--ablation none|rewriteHeuristics] [--threshold 0.0-1.0] [--mode rewrite.short] [--case substring] [--defaults]" >&2
      exit 2
      ;;
  esac
done

case "$MODEL_OPTION" in
  stable|experimental)
    ;;
  *)
    echo "invalid model option: $MODEL_OPTION" >&2
    exit 2
    ;;
esac

case "$QUANT_PRESET" in
  fast|balanced|quality)
    ;;
  *)
    echo "invalid quant preset: $QUANT_PRESET" >&2
    exit 2
    ;;
esac

case "$MODEL_PROFILE" in
  fast|balanced|quality)
    ;;
  *)
    echo "invalid model profile: $MODEL_PROFILE" >&2
    exit 2
    ;;
esac

case "$SUITE" in
  dev|holdout|all)
    ;;
  *)
    echo "invalid suite: $SUITE" >&2
    exit 2
    ;;
esac

case "$ABLATION" in
  none|rewriteHeuristics)
    ;;
  *)
    echo "invalid ablation: $ABLATION" >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"

TEXTKIT_RUN_GOLDEN_EVAL=1 \
TEXTKIT_EVAL_MODEL="$MODEL_OPTION" \
TEXTKIT_EVAL_QUANT="$QUANT_PRESET" \
TEXTKIT_EVAL_MODEL_PROFILE="$MODEL_PROFILE" \
TEXTKIT_EVAL_SUITE="$SUITE" \
TEXTKIT_EVAL_ABLATION="$ABLATION" \
TEXTKIT_EVAL_MIN_PASS_RATE="$MIN_PASS_RATE" \
TEXTKIT_EVAL_MODE="$MODE_FILTER" \
TEXTKIT_EVAL_CASE="$CASE_FILTER" \
TEXTKIT_EVAL_USE_STRICT_PROFILE="$USE_STRICT_PROFILE" \
xcrun swift test --filter GoldenEvalHarnessTests
