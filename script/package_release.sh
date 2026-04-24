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
# shellcheck source=/dev/null
source "$ROOT_DIR/script/updater_config.sh"
DIST_DIR="$ROOT_DIR/dist/release"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_EXECUTABLE_NAME="TextKit"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE_NAME"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ZIP_PATH="$DIST_DIR/$ZIP_NAME.zip"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"
APPCAST_PATH="$DIST_DIR/appcast.xml"
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
    v*)
      VERSION="${1#v}"
      shift
      ;;
    [0-9]*)
      VERSION="$1"
      shift
      ;;
    *)
      echo "usage: $0 [--fresh-first-run] [--version x.y.z|x.y.z] [--open]" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Release version is required." >&2
  exit 2
fi

if [[ "$MODE" == "fresh-first-run" ]]; then
  APP_BINARY="$APP_MACOS/TextKit-bin"
fi

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
  if [[ "$MODE" != "fresh-first-run" ]]; then
    return 0
  fi

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
    'BACKENDS_DIR="$RUNTIME_ROOT/backends"' \
    '' \
    'select_backend() {' \
    '  local cpu_brand candidate' \
    '  cpu_brand="$(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"' \
    '' \
    '  case "$cpu_brand" in' \
    '    *M4*)' \
    '      for candidate in "$BACKENDS_DIR/libggml-cpu-apple_m4.so" "$BACKENDS_DIR/libggml-cpu-apple_m2_m3.so" "$BACKENDS_DIR/libggml-cpu-apple_m1.so"; do' \
    '        [[ -f "$candidate" ]] && { printf "%s\n" "$candidate"; return 0; }' \
    '      done' \
    '      ;;' \
    '    *M2*|*M3*)' \
    '      for candidate in "$BACKENDS_DIR/libggml-cpu-apple_m2_m3.so" "$BACKENDS_DIR/libggml-cpu-apple_m1.so" "$BACKENDS_DIR/libggml-cpu-apple_m4.so"; do' \
    '        [[ -f "$candidate" ]] && { printf "%s\n" "$candidate"; return 0; }' \
    '      done' \
    '      ;;' \
    '    *)' \
    '      for candidate in "$BACKENDS_DIR/libggml-cpu-apple_m1.so" "$BACKENDS_DIR/libggml-cpu-apple_m2_m3.so" "$BACKENDS_DIR/libggml-cpu-apple_m4.so"; do' \
    '        [[ -f "$candidate" ]] && { printf "%s\n" "$candidate"; return 0; }' \
    '      done' \
    '      ;;' \
    '  esac' \
    '' \
    '  return 1' \
    '}' \
    '' \
    'export TEXTKIT_RUNTIME_ROOT="$RUNTIME_ROOT"' \
    'if BACKEND_PATH="$(select_backend)"; then' \
    '  export GGML_BACKEND_PATH="$BACKEND_PATH"' \
    'fi' \
    'export PATH="$RUNTIME_ROOT/bin${PATH:+:$PATH}"' \
    'export DYLD_LIBRARY_PATH="$RUNTIME_ROOT/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"' \
    'export DYLD_FALLBACK_LIBRARY_PATH="$RUNTIME_ROOT/lib${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"' \
    '' \
    'exec -a "TextKit" "$SCRIPT_DIR/TextKit-bin"' \
    >"$APP_MACOS/TextKit"

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
    "  <string>$APP_EXECUTABLE_NAME</string>" \
    '  <key>CFBundleIdentifier</key>' \
    "  <string>$BUNDLE_ID</string>" \
    '  <key>CFBundleIconFile</key>' \
    '  <string>AppIcon</string>' \
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
    '  <key>SUAutomaticallyUpdate</key>' \
    '  <true/>' \
    '  <key>SUEnableAutomaticChecks</key>' \
    '  <true/>' \
    '  <key>SUFeedURL</key>' \
    "  <string>$SPARKLE_APPCAST_URL</string>" \
    '  <key>SUPublicEDKey</key>' \
    "  <string>$SPARKLE_PUBLIC_ED_KEY</string>" \
    '  <key>SUVerifyUpdateBeforeExtraction</key>' \
    '  <true/>' \
    '</dict>' \
    '</plist>' \
    >"$INFO_PLIST"
}

copy_sparkle_framework() {
  local sparkle_framework
  sparkle_framework="$("$ROOT_DIR/script/resolve_sparkle_distribution.sh" --framework)"

  mkdir -p "$APP_FRAMEWORKS"
  /usr/bin/ditto "$sparkle_framework" "$APP_FRAMEWORKS/Sparkle.framework"
}

ensure_app_framework_rpath() {
  if ! otool -l "$APP_BINARY" | grep -A2 LC_RPATH | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY"
  fi
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

codesign_embedded_sparkle() {
  local sparkle_framework="$APP_FRAMEWORKS/Sparkle.framework"

  [[ -d "$sparkle_framework" ]] || return 0

  codesign_artifact "$sparkle_framework/Versions/B/Autoupdate"
  codesign_artifact "$sparkle_framework/Versions/B/XPCServices/Downloader.xpc"
  codesign_artifact "$sparkle_framework/Versions/B/XPCServices/Installer.xpc"
  codesign_artifact "$sparkle_framework/Versions/B/Updater.app"
  codesign_artifact "$sparkle_framework"
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
SWIFT_MODULE_CACHE_DIR="$ROOT_DIR/.tmp/module-cache"
CLANG_MODULE_CACHE_DIR="$SWIFT_MODULE_CACHE_DIR/clang"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  TOOLCHAIN_SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
  if [[ -x "$TOOLCHAIN_SWIFT" ]]; then
    SWIFT_BIN="$TOOLCHAIN_SWIFT"
  fi
fi

echo "Building $APP_DISPLAY_NAME ($BUILD_CONFIGURATION)..."
mkdir -p "$SWIFT_MODULE_CACHE_DIR" "$CLANG_MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE_DIR"
"$SWIFT_BIN" -module-cache-path "$SWIFT_MODULE_CACHE_DIR" "$ROOT_DIR/script/render_app_icon.swift"
"$SWIFT_BIN" build -c "$BUILD_CONFIGURATION" -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE_DIR"
BUILD_BINARY="$("$SWIFT_BIN" build -c "$BUILD_CONFIGURATION" -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE_DIR" --show-bin-path)/TextKit"

rm -rf "$APP_BUNDLE" "$STAGING_DIR" "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
ensure_app_framework_rpath

if [[ -d "$ROOT_DIR/Resources" ]]; then
  cp -R "$ROOT_DIR/Resources/." "$APP_RESOURCES/"
fi

copy_sparkle_framework
write_launcher
write_info_plist
"$ROOT_DIR/script/bundle_llama_runtime.sh" "$APP_BUNDLE"
codesign_artifact "$APP_BINARY"
sign_runtime_artifacts
codesign_embedded_sparkle
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

if [[ -n "${SPARKLE_PRIVATE_ED_KEY:-}" ]]; then
  "$ROOT_DIR/script/generate_appcast.sh" "$VERSION" "$ZIP_PATH" "$APPCAST_PATH"
  echo "Built appcast: $APPCAST_PATH"
else
  echo "Skipping Sparkle appcast generation because SPARKLE_PRIVATE_ED_KEY is not set."
fi

echo "Built app: $APP_BUNDLE"
echo "Built ZIP: $ZIP_PATH"
shasum -a 256 "$ZIP_PATH"
echo "Built DMG: $DMG_PATH"
shasum -a 256 "$DMG_PATH"

if [[ "$OPEN_RESULT" -eq 1 ]]; then
  open -R "$DMG_PATH"
fi
