#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version is required}"
ZIP_PATH="${2:?zip path is required}"
OUTPUT_PATH="${3:-dist/release/textkit.rb}"
REPOSITORY="${GITHUB_REPOSITORY:-}"
BUNDLE_ID="com.mikedrake.TextKit"

if [[ -z "$REPOSITORY" ]]; then
  echo "GITHUB_REPOSITORY must be set to render the cask file." >&2
  exit 2
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "ZIP artifact not found: $ZIP_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
HOMEPAGE="https://github.com/$REPOSITORY"
URL="$HOMEPAGE/releases/download/v$VERSION/TextKit.zip"

cat >"$OUTPUT_PATH" <<EOF
cask "textkit" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$URL"
  name "TextKit"
  desc "Native macOS menu bar utility for local clipboard text transformation"
  homepage "$HOMEPAGE"

  depends_on macos: ">= :tahoe"

  auto_updates true

  app "TextKit.app"

  zap trash: [
    "~/Library/Application Support/TextKit",
    "~/Library/Preferences/$BUNDLE_ID.plist",
    "~/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct-GGUF",
    "~/.cache/huggingface/hub/models--AaryanK--Qwen3.5-0.8B-GGUF",
    "~/Library/Caches/llama.cpp/Qwen_Qwen2.5-0.5B-Instruct-GGUF_preset.ini",
    "~/Library/Caches/llama.cpp/AaryanK_Qwen3.5-0.8B-GGUF_preset.ini",
  ]
end
EOF

printf 'Wrote %s\n' "$OUTPUT_PATH"
