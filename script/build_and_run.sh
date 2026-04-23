#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TextKit"
BUNDLE_ID="com.mikedrake.TextKit"
MIN_SYSTEM_VERSION="26.0"
XCODE_DEVELOPER_DIR="/Volumes/SSD/Applications/Xcode.app/Contents/Developer"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME-bin"
APP_RESOURCES="$APP_CONTENTS/Resources"
INFO_PLIST="$APP_CONTENTS/Info.plist"

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
  printf '%s\n' \
    '#!/bin/zsh' \
    'set -euo pipefail' \
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
    >"$APP_MACOS/$APP_NAME"
  chmod +x "$APP_MACOS/$APP_NAME"
}

write_info_plist() {
  printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
    '<plist version="1.0">' \
    '<dict>' \
    '  <key>CFBundleDisplayName</key>' \
    "  <string>$APP_NAME</string>" \
    '  <key>CFBundleExecutable</key>' \
    "  <string>$APP_NAME</string>" \
    '  <key>CFBundleIdentifier</key>' \
    "  <string>$BUNDLE_ID</string>" \
    '  <key>CFBundleIconFile</key>' \
    '  <string>AppIcon</string>' \
    '  <key>CFBundleName</key>' \
    "  <string>$APP_NAME</string>" \
    '  <key>CFBundlePackageType</key>' \
    '  <string>APPL</string>' \
    '  <key>CFBundleShortVersionString</key>' \
    '  <string>0.1.0</string>' \
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
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

launch_fresh_setup_app() {
  local run_id fresh_root cache_root defaults_suite

  run_id="$(date +%Y%m%d-%H%M%S)"
  fresh_root="$ROOT_DIR/.tmp/fresh-setup/$run_id"
  cache_root="$fresh_root/xdg-cache"
  defaults_suite="$BUNDLE_ID.fresh.$run_id"

  mkdir -p "$cache_root"

  /bin/launchctl setenv TEXTKIT_USER_DEFAULTS_SUITE "$defaults_suite"
  /bin/launchctl setenv XDG_CACHE_HOME "$cache_root"

  open_app

  sleep 2
  pgrep -x "$APP_NAME" >/dev/null || pgrep -x "$APP_NAME-bin" >/dev/null || {
    /bin/launchctl unsetenv TEXTKIT_USER_DEFAULTS_SUITE
    /bin/launchctl unsetenv XDG_CACHE_HOME
    return 1
  }

  /bin/launchctl unsetenv TEXTKIT_USER_DEFAULTS_SUITE
  /bin/launchctl unsetenv XDG_CACHE_HOME

  printf '%s\n' \
    'Fresh setup sandbox is running.' \
    "Defaults suite: $defaults_suite" \
    "Model cache: $cache_root"
}

DEVELOPER_DIR="$(resolve_developer_dir)"
export DEVELOPER_DIR

SWIFT_BIN="swift"
SWIFT_MODULE_CACHE_DIR="$ROOT_DIR/.tmp/module-cache"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  TOOLCHAIN_SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
  if [[ -x "$TOOLCHAIN_SWIFT" ]]; then
    SWIFT_BIN="$TOOLCHAIN_SWIFT"
  fi
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$APP_NAME-bin" >/dev/null 2>&1 || true

mkdir -p "$SWIFT_MODULE_CACHE_DIR"
"$SWIFT_BIN" -module-cache-path "$SWIFT_MODULE_CACHE_DIR" "$ROOT_DIR/script/render_app_icon.swift"
"$SWIFT_BIN" build
BUILD_BINARY="$("$SWIFT_BIN" build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -d "$ROOT_DIR/Resources" ]]; then
  cp -R "$ROOT_DIR/Resources/." "$APP_RESOURCES/"
fi

write_launcher
write_info_plist
"$ROOT_DIR/script/bundle_llama_runtime.sh" "$APP_BUNDLE"
codesign --force --sign - "$APP_BINARY"
codesign --force --deep --sign - "$APP_BUNDLE"

case "$MODE" in
  run)
    open_app
    ;;
  --fresh-setup|fresh-setup)
    launch_fresh_setup_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null || pgrep -x "$APP_NAME-bin" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--fresh-setup|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
