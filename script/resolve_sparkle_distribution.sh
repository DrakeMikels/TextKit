#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/script/updater_config.sh"

SPARKLE_CACHE_DIR="$ROOT_DIR/.build/vendor/Sparkle/$SPARKLE_VERSION"
SPARKLE_ARCHIVE_PATH="$SPARKLE_CACHE_DIR/Sparkle-for-Swift-Package-Manager.zip"
SPARKLE_DOWNLOAD_URL="https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-for-Swift-Package-Manager.zip"
SPARKLE_FRAMEWORK_PATH="$SPARKLE_CACHE_DIR/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
SPARKLE_BIN_DIR="$SPARKLE_CACHE_DIR/bin"

prepare_distribution() {
  if [[ -d "$SPARKLE_FRAMEWORK_PATH" && -d "$SPARKLE_BIN_DIR" ]]; then
    return 0
  fi

  mkdir -p "$SPARKLE_CACHE_DIR"

  if [[ ! -f "$SPARKLE_ARCHIVE_PATH" ]]; then
    curl -L "$SPARKLE_DOWNLOAD_URL" -o "$SPARKLE_ARCHIVE_PATH"
  fi

  local extract_dir
  extract_dir="$(mktemp -d "$SPARKLE_CACHE_DIR/extract.XXXXXX")"
  unzip -q -o "$SPARKLE_ARCHIVE_PATH" -d "$extract_dir"

  rm -rf "$SPARKLE_CACHE_DIR/bin" \
    "$SPARKLE_CACHE_DIR/Sparkle.xcframework" \
    "$SPARKLE_CACHE_DIR/CHANGELOG" \
    "$SPARKLE_CACHE_DIR/INSTALL" \
    "$SPARKLE_CACHE_DIR/LICENSE" \
    "$SPARKLE_CACHE_DIR/SampleAppcast.xml"

  mv "$extract_dir/bin" "$SPARKLE_CACHE_DIR/bin"
  mv "$extract_dir/Sparkle.xcframework" "$SPARKLE_CACHE_DIR/Sparkle.xcframework"
  mv "$extract_dir/CHANGELOG" "$SPARKLE_CACHE_DIR/CHANGELOG"
  mv "$extract_dir/INSTALL" "$SPARKLE_CACHE_DIR/INSTALL"
  mv "$extract_dir/LICENSE" "$SPARKLE_CACHE_DIR/LICENSE"
  mv "$extract_dir/SampleAppcast.xml" "$SPARKLE_CACHE_DIR/SampleAppcast.xml"

  rm -rf "$extract_dir"
}

prepare_distribution

case "${1:---root}" in
  --root)
    printf '%s\n' "$SPARKLE_CACHE_DIR"
    ;;
  --framework)
    printf '%s\n' "$SPARKLE_FRAMEWORK_PATH"
    ;;
  --bin-dir)
    printf '%s\n' "$SPARKLE_BIN_DIR"
    ;;
  *)
    echo "usage: $0 [--root|--framework|--bin-dir]" >&2
    exit 2
    ;;
esac
