#!/usr/bin/env bash
set -euo pipefail

MODE="standard"
OPEN_RESULT=0

APP_NAME="TextKit"
APP_DISPLAY_NAME="TextKit"
BUNDLE_ID="com.mikedrake.TextKit"
DMG_NAME="TextKit"
VOLUME_NAME="Install TextKit"
VERSION="0.1.0"
BUILD_CONFIGURATION="release"
MIN_SYSTEM_VERSION="26.0"
XCODE_DEVELOPER_DIR="/Volumes/SSD/Applications/Xcode.app/Contents/Developer"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh-first-run)
      MODE="fresh-first-run"
      APP_NAME="TextKit First Run Test"
      APP_DISPLAY_NAME="TextKit First Run Test"
      BUNDLE_ID="com.mikedrake.TextKit.FirstRunTest"
      DMG_NAME="TextKit-First-Run-Test"
      VOLUME_NAME="Install TextKit Test"
      shift
      ;;
    --open)
      OPEN_RESULT=1
      shift
      ;;
    *)
      echo "usage: $0 [--fresh-first-run] [--open]" >&2
      exit 2
      ;;
  esac
done

DIST_DIR="$ROOT_DIR/dist/release"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
INFO_PLIST="$APP_CONTENTS/Info.plist"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"

if [[ -d "$XCODE_DEVELOPER_DIR" ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-$XCODE_DEVELOPER_DIR}"
fi

mkdir -p "$ROOT_DIR/.tmp/home" "$ROOT_DIR/.tmp/swift-tmp" "$ROOT_DIR/.tmp/xdg-cache"
export HOME="${HOME:-$ROOT_DIR/.tmp/home}"
export TMPDIR="${TMPDIR:-$ROOT_DIR/.tmp/swift-tmp}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$ROOT_DIR/.tmp/xdg-cache}"

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

rm -rf "$APP_BUNDLE" "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

if [[ "$MODE" == "fresh-first-run" ]]; then
  cp "$BUILD_BINARY" "$APP_MACOS/TextKit-bin"
  chmod +x "$APP_MACOS/TextKit-bin"

  printf '%s\n' \
    '#!/bin/zsh' \
    'set -euo pipefail' \
    '' \
    'APP_SUPPORT="$HOME/Library/Application Support/TextKit First Run Test"' \
    'mkdir -p "$APP_SUPPORT/xdg-cache"' \
    '' \
    'export TEXTKIT_USER_DEFAULTS_SUITE="com.mikedrake.TextKit.FirstRunTest"' \
    'export XDG_CACHE_HOME="$APP_SUPPORT/xdg-cache"' \
    '' \
    'SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"' \
    'exec "$SCRIPT_DIR/TextKit-bin"' \
    >"$APP_MACOS/TextKit"
  chmod +x "$APP_MACOS/TextKit"
else
  cp "$BUILD_BINARY" "$APP_MACOS/TextKit"
  chmod +x "$APP_MACOS/TextKit"
fi

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
  '  <string>1</string>' \
  '  <key>LSMinimumSystemVersion</key>' \
  "  <string>$MIN_SYSTEM_VERSION</string>" \
  '  <key>LSUIElement</key>' \
  '  <true/>' \
  '  <key>NSPrincipalClass</key>' \
  '  <string>NSApplication</string>' \
  '</dict>' \
  '</plist>' \
  >"$INFO_PLIST"

codesign --force --deep --sign - "$APP_BUNDLE"

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

echo "Creating DMG..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  >/dev/null

echo "Built app: $APP_BUNDLE"
echo "Built DMG: $DMG_PATH"

if [[ "$OPEN_RESULT" -eq 1 ]]; then
  open -R "$DMG_PATH"
fi
