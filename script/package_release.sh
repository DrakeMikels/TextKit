#!/usr/bin/env bash
set -euo pipefail

MODE="standard"
OPEN_RESULT=0
VERSION="0.1.0"

APP_NAME="TextKit"
APP_DISPLAY_NAME="TextKit"
BUNDLE_ID="com.mikedrake.TextKit"
DMG_NAME="TextKit"
ZIP_NAME="TextKit"
VOLUME_NAME="Install TextKit"
BUILD_CONFIGURATION="release"
MIN_SYSTEM_VERSION="26.0"
XCODE_DEVELOPER_DIR="/Volumes/SSD/Applications/Xcode.app/Contents/Developer"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/release"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/TextKit-bin"
APP_RESOURCES="$APP_CONTENTS/Resources"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ZIP_PATH="$DIST_DIR/$ZIP_NAME.zip"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"
API_KEY_PATH="$DIST_DIR/AuthKey.p8"

cleanup_release_artifacts() {
  rm -f "$API_KEY_PATH"
}

trap cleanup_release_artifacts EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh-first-run)
      MODE="fresh-first-run"
      APP_NAME="TextKit First Run Test"
      APP_DISPLAY_NAME="TextKit First Run Test"
      BUNDLE_ID="com.mikedrake.TextKit.FirstRunTest"
      DMG_NAME="TextKit-First-Run-Test"
      ZIP_NAME="TextKit-First-Run-Test"
      VOLUME_NAME="Install TextKit Test"
      shift
      ;;
    --open)
      OPEN_RESULT=1
      shift
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    *)
      echo "usage: $0 [--fresh-first-run] [--version x.y.z] [--open]" >&2
      exit 2
      ;;
  esac
done

resolve_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" ]] && [[ -d "$DEVELOPER_DIR" ]]; then
    printf '%s\n' "$DEVELOPER_DIR"
    return 0
  fi

  local candidates=(
    "/Applications/Xcode.app/Contents/Developer"
    "$XCODE_DEVELOPER_DIR"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  xcode-select -p 2>/dev/null || true
}

write_launcher() {
  if [[ "$MODE" == "fresh-first-run" ]]; then
    printf '%s\n' \
      '#!/bin/zsh' \
      'set -euo pipefail' \
      '' \
      'APP_SUPPORT="$HOME/Library/Application Support/TextKit First Run Test"' \
      'mkdir -p "$APP_SUPPORT/xdg-cache"' \
      '' \
      'export TEXTKIT_USER_DEFAULTS_SUITE="${TEXTKIT_USER_DEFAULTS_SUITE:-com.mikedrake.TextKit.FirstRunTest}"' \
      'export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$APP_SUPPORT/xdg-cache}"' \
      '' \
      'SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"' \
      'RUNTIME_ROOT="$SCRIPT_DIR/../Resources/Runtime"' \
      '' \
      'export TEXTKIT_RUNTIME_ROOT="$RUNTIME_ROOT"' \
      'export GGML_BACKEND_PATH="$RUNTIME_ROOT/backends"' \
      'export PATH="$RUNTIME_ROOT/bin${PATH:+:$PATH}"' \
      'export DYLD_LIBRARY_PATH="$RUNTIME_ROOT/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"' \
      'export DYLD_FALLBACK_LIBRARY_PATH="$RUNTIME_ROOT/lib${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"' \
      '' \
      'exec -a "TextKit" "$SCRIPT_DIR/TextKit-bin"' \
      >"$APP_MACOS/TextKit"
  else
    printf '%s\n' \
      '#!/bin/zsh' \
      'set -euo pipefail' \
      '' \
      'SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"' \
      'RUNTIME_ROOT="$SCRIPT_DIR/../Resources/Runtime"' \
      '' \
      'export TEXTKIT_RUNTIME_ROOT="$RUNTIME_ROOT"' \
      'export GGML_BACKEND_PATH="$RUNTIME_ROOT/backends"' \
      'export PATH="$RUNTIME_ROOT/bin${PATH:+:$PATH}"' \
      'export DYLD_LIBRARY_PATH="$RUNTIME_ROOT/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"' \
      'export DYLD_FALLBACK_LIBRARY_PATH="$RUNTIME_ROOT/lib${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"' \
      '' \
      'exec -a "TextKit" "$SCRIPT_DIR/TextKit-bin"' \
      >"$APP_MACOS/TextKit"
  fi

  chmod +x "$APP_MACOS/TextKit"
}

write_info_plist() {
  printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
    '<plist version="1.0">' \
    '<dict>' \
    '  <key>CFBundleDisplayName</key>' \
    "  <string>$APP_DISPLAY_NAME</string>" \
    '  <key>CFBundleExecutable</key>' \
    '  <string>TextKit</string>' \
    '  <key>CFBundleIdentifier</key>' \
    "  <string>$BUNDLE_ID</string>" \
    '  <key>CFBundleName</key>' \
    "  <string>$APP_DISPLAY_NAME</string>" \
    '  <key>CFBundlePackageType</key>' \
    '  <string>APPL</string>' \
    '  <key>CFBundleShortVersionString</key>' \
    "  <string>$VERSION</string>" \
    '  <key>CFBundleVersion</key>' \
    "  <string>$VERSION</string>" \
    '  <key>LSMinimumSystemVersion</key>' \
    "  <string>$MIN_SYSTEM_VERSION</string>" \
    '  <key>LSUIElement</key>' \
    '  <true/>' \
    '  <key>NSPrincipalClass</key>' \
    '  <string>NSApplication</string>' \
    '</dict>' \
    '</plist>' \
    >"$INFO_PLIST"
}

codesign_artifact() {
  local artifact_path="$1"

  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign \
      --force \
      --options runtime \
      --timestamp \
      --sign "$CODESIGN_IDENTITY" \
      "$artifact_path"
  else
    codesign --force --sign - "$artifact_path"
  fi
}

sign_runtime_artifacts() {
  local runtime_dir="$APP_RESOURCES/Runtime"

  if [[ -d "$runtime_dir/lib" ]]; then
    find "$runtime_dir/lib" -type f \( -name '*.dylib' -o -name '*.so' \) | sort | while read -r artifact; do
      codesign_artifact "$artifact"
    done
  fi

  if [[ -d "$runtime_dir/backends" ]]; then
    find "$runtime_dir/backends" -type f -name '*.so' | sort | while read -r artifact; do
      codesign_artifact "$artifact"
    done
  fi

  if [[ -d "$runtime_dir/bin" ]]; then
    find "$runtime_dir/bin" -type f | sort | while read -r artifact; do
      chmod +x "$artifact"
      codesign_artifact "$artifact"
    done
  fi
}

package_zip() {
  rm -f "$ZIP_PATH"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
}

package_dmg() {
  rm -rf "$STAGING_DIR"
  rm -f "$DMG_PATH"
  mkdir -p "$STAGING_DIR"
  cp -R "$APP_BUNDLE" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"

  printf '%s\n' \
    "$APP_DISPLAY_NAME" \
    '' \
    '1. Drag the app into Applications.' \
    '2. Open it from Applications to test the first-run experience.' \
    '' \
    "Mode: $MODE" \
    >"$STAGING_DIR/README.txt"

  hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    >/dev/null

  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign \
      --force \
      --timestamp \
      --sign "$CODESIGN_IDENTITY" \
      "$DMG_PATH"
  fi
}

notary_submit() {
  local artifact_path="$1"

  if [[ -n "${APPLE_API_KEY_P8:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]]; then
    if [[ ! -f "$API_KEY_PATH" ]]; then
      printf '%s' "$APPLE_API_KEY_P8" >"$API_KEY_PATH"
      chmod 600 "$API_KEY_PATH"
    fi

    xcrun notarytool submit \
      "$artifact_path" \
      --key "$API_KEY_PATH" \
      --key-id "$APPLE_API_KEY_ID" \
      --issuer "$APPLE_API_ISSUER_ID" \
      --wait
    return
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit \
      "$artifact_path" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  fi
}

DEVELOPER_DIR="$(resolve_developer_dir)"
export DEVELOPER_DIR

mkdir -p "$ROOT_DIR/.tmp/home" "$ROOT_DIR/.tmp/swift-tmp" "$ROOT_DIR/.tmp/xdg-cache"
export HOME="${HOME:-$ROOT_DIR/.tmp/home}"
export TMPDIR="${TMPDIR:-$ROOT_DIR/.tmp/swift-tmp}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$ROOT_DIR/.tmp/xdg-cache}"

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-${APPLE_DEVELOPER_ID_IDENTITY:-}}"
export CODESIGN_IDENTITY

SWIFT_BIN="swift"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  TOOLCHAIN_SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
  if [[ -x "$TOOLCHAIN_SWIFT" ]]; then
    SWIFT_BIN="$TOOLCHAIN_SWIFT"
  fi
fi

echo "Building $APP_DISPLAY_NAME ($BUILD_CONFIGURATION)..."
"$SWIFT_BIN" build -c "$BUILD_CONFIGURATION"
BUILD_BINARY="$("$SWIFT_BIN" build -c "$BUILD_CONFIGURATION" --show-bin-path)/TextKit"

rm -rf "$APP_BUNDLE" "$STAGING_DIR" "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

write_launcher
write_info_plist
"$ROOT_DIR/script/bundle_llama_runtime.sh" "$APP_BUNDLE"
codesign_artifact "$APP_BINARY"
sign_runtime_artifacts
codesign_artifact "$APP_BUNDLE"

package_zip

if [[ -n "${CODESIGN_IDENTITY:-}" ]] && { [[ -n "${APPLE_API_KEY_P8:-}" && -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" ]] || [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; }; then
  notary_submit "$ZIP_PATH"
  xcrun stapler staple "$APP_BUNDLE"
  package_zip
  package_dmg
  notary_submit "$DMG_PATH"
  xcrun stapler staple "$DMG_PATH"
else
  package_dmg
fi

echo "Built app: $APP_BUNDLE"
echo "Built ZIP: $ZIP_PATH"
echo "Built DMG: $DMG_PATH"

if [[ "$OPEN_RESULT" -eq 1 ]]; then
  open -R "$DMG_PATH"
fi
