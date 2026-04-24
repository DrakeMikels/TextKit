#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version is required}"
ZIP_PATH="${2:?zip path is required}"
OUTPUT_PATH="${3:-dist/release/appcast.xml}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/script/updater_config.sh"

SPARKLE_BIN_DIR="$("$ROOT_DIR/script/resolve_sparkle_distribution.sh" --bin-dir)"
SIGN_UPDATE="$SPARKLE_BIN_DIR/sign_update"

WORK_DIR="$(mktemp -d "$ROOT_DIR/dist/appcast.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

EXTRACT_DIR="$WORK_DIR/extracted"
mkdir -p "$EXTRACT_DIR"
/usr/bin/ditto -x -k "$ZIP_PATH" "$EXTRACT_DIR"

APP_PATH="$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Could not locate an .app bundle inside $ZIP_PATH" >&2
  exit 2
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
APP_BINARY="$(find "$APP_PATH/Contents/MacOS" -maxdepth 1 -type f | head -n 1)"
if [[ -z "$APP_BINARY" ]]; then
  echo "Could not locate the app binary inside $APP_PATH" >&2
  exit 2
fi

SHORT_VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" 2>/dev/null \
    || printf '%s' "$VERSION"
)"
BUILD_VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null \
    || printf '%s' "$VERSION"
)"
MINIMUM_SYSTEM_VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST" 2>/dev/null \
    || printf '%s' "26.0"
)"
HARDWARE_REQUIREMENTS="$(lipo -archs "$APP_BINARY" | tr ' ' ',' | tr -d '\n')"
ARCHIVE_LENGTH="$(stat -f '%z' "$ZIP_PATH")"
PUBLISH_DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
DOWNLOAD_URL="$SPARKLE_RELEASE_DOWNLOAD_BASE/v$VERSION/$(basename "$ZIP_PATH")"

sign_with_private_key() {
  printf '%s' "$SPARKLE_PRIVATE_ED_KEY" | "$SIGN_UPDATE" --ed-key-file - -p "$1"
}

sign_with_keychain() {
  "$SIGN_UPDATE" --account "$SPARKLE_KEY_ACCOUNT" -p "$1"
}

if [[ -n "${SPARKLE_PRIVATE_ED_KEY:-}" ]]; then
  ARCHIVE_SIGNATURE="$(sign_with_private_key "$ZIP_PATH")"
else
  ARCHIVE_SIGNATURE="$(sign_with_keychain "$ZIP_PATH")"
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
cat >"$OUTPUT_PATH" <<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>TextKit</title>
    <link>https://github.com/$SPARKLE_REPOSITORY</link>
    <item>
      <title>$SHORT_VERSION</title>
      <pubDate>$PUBLISH_DATE</pubDate>
      <link>https://github.com/$SPARKLE_REPOSITORY/releases/tag/v$VERSION</link>
      <sparkle:version>$BUILD_VERSION</sparkle:version>
      <sparkle:shortVersionString>$SHORT_VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MINIMUM_SYSTEM_VERSION</sparkle:minimumSystemVersion>
      <sparkle:hardwareRequirements>$HARDWARE_REQUIREMENTS</sparkle:hardwareRequirements>
      <enclosure
        url="$DOWNLOAD_URL"
        length="$ARCHIVE_LENGTH"
        type="application/octet-stream"
        sparkle:edSignature="$ARCHIVE_SIGNATURE"/>
    </item>
  </channel>
</rss>
EOF

if [[ -n "${SPARKLE_PRIVATE_ED_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_ED_KEY" | "$SIGN_UPDATE" --ed-key-file - "$OUTPUT_PATH" >/dev/null
else
  "$SIGN_UPDATE" --account "$SPARKLE_KEY_ACCOUNT" "$OUTPUT_PATH" >/dev/null
fi

printf 'Wrote %s\n' "$OUTPUT_PATH"
