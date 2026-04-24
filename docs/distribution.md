# TextKit Distribution

This document defines the release path for TextKit GitHub Releases, ZIP/DMG downloads, and Homebrew cask publishing.

## Release Outputs

The release workflow produces:

- `TextKit.zip`: Homebrew cask source artifact.
- `TextKit.dmg`: direct download artifact for non-Homebrew users.
- `appcast.xml`: Sparkle update feed for in-app update checks.
- `textkit.rb`: generated Homebrew cask for tap publishing.

Artifacts are uploaded to the GitHub Release for tag `v<version>`.

## Release Triggers

Create a release by pushing a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Or run the `Release` workflow manually from GitHub Actions with a version input such as `0.1.0`.

## Required GitHub Actions Secrets

Signing and notarization use repository secrets. Do not commit these values to git.
The release workflow fails before packaging if these values are missing, because public GitHub Release assets should be signed and notarized.

| Secret | Purpose |
| --- | --- |
| `APPLE_DEVELOPER_ID_CERTIFICATE_P12` | Base64-encoded Developer ID Application `.p12` certificate. |
| `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password for the `.p12` certificate. |
| `APPLE_DEVELOPER_ID_IDENTITY` | Codesign identity name, for example `Developer ID Application: ...`. |
| `APPLE_API_KEY_P8` | App Store Connect API key private key contents. |
| `APPLE_API_KEY_ID` | App Store Connect API key ID. |
| `APPLE_API_ISSUER_ID` | App Store Connect issuer UUID. |
| `SPARKLE_PRIVATE_ED_KEY` | Private EdDSA key used to sign Sparkle update archives and appcasts. |

Alternative notarization secrets are also supported by `script/package_release.sh`, but the API key path above is preferred:

| Secret | Purpose |
| --- | --- |
| `APPLE_ID` | Apple ID email for notarytool password auth. |
| `APPLE_TEAM_ID` | Apple Developer Team ID. |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for notarytool password auth. |

## Optional Homebrew Tap Secrets

The workflow can publish the generated cask to a tap repository when these are set:

| Secret | Purpose |
| --- | --- |
| `HOMEBREW_TAP_REPOSITORY` | Tap repository in `owner/repo` form. Current expected tap: `DrakeMikels/homebrew-tap`. |
| `HOMEBREW_TAP_GITHUB_TOKEN` | Token with contents write access to the tap repository. |

Optional repository variable:

| Variable | Purpose |
| --- | --- |
| `HOMEBREW_TAP_CASK_PATH` | Destination path inside the tap. Defaults to `Casks/textkit.rb`. |

## Local Package Validation

Build unsigned local artifacts:

```bash
./script/package_release.sh --version 0.1.0
```

Generate a cask from the local ZIP:

```bash
GITHUB_REPOSITORY=DrakeMikels/TextKit ./script/render_cask.sh 0.1.0 dist/release/TextKit.zip dist/release/textkit.rb
```

Validate the generated cask syntax locally:

```bash
brew style --cask dist/release/textkit.rb
```

## User Install Paths

Direct download:

1. Download `TextKit.dmg` from the GitHub Release.
2. Drag `TextKit.app` into Applications.
3. Open TextKit and complete first-run model setup.

Homebrew:

```bash
brew tap <owner>/<tap>
brew install --cask textkit
```

Signed release builds also support in-app update checks through Sparkle. The generated Homebrew cask sets `auto_updates true`, so users can either update in-app or run:

```bash
brew update
brew upgrade --cask textkit
```

## Security Notes

- `dist/`, `.env*`, `.p8`, certificates, keychains, provisioning profiles, ZIPs, DMGs, PKGs, and local planning docs are ignored by git.
- Release scripts read credentials only from environment variables or GitHub Actions secrets.
- The generated cask points at the GitHub Release ZIP and never embeds signing or notarization credentials.
- Sparkle's public EdDSA key is committed in `script/updater_config.sh`; the matching private key must stay outside the repo and be stored only as `SPARKLE_PRIVATE_ED_KEY` in GitHub Actions secrets.
