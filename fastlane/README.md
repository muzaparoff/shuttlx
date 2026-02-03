# Fastlane Setup for ShuttlX

This directory contains the Fastlane configuration for building, testing, and deploying ShuttlX to the App Store.

## Prerequisites

1. **Ruby** (3.0+) and **Bundler** installed
2. **Xcode 16+** with iOS 18 and watchOS 11 SDKs
3. An **Apple Developer account** with the ShuttlX app registered
4. An **App Store Connect API Key** (recommended for CI/CD)

## Quick Start

```bash
# Install dependencies
bundle install

# Run tests (iOS + watchOS simulators)
bundle exec fastlane test

# Build and upload to TestFlight
bundle exec fastlane beta

# Build and upload for App Store review
bundle exec fastlane release
```

## Setting Up the App Store Connect API Key

1. Go to [App Store Connect > Users and Access > Integrations > App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
2. Click the "+" button to create a new key
3. Give it a name (e.g., "ShuttlX CI/CD") and select the **Admin** role
4. Download the `.p8` file (you can only download it once)
5. Note the **Key ID** and **Issuer ID** from the page

## GitHub Secrets Configuration

Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions):

| Secret Name | Description | How to Get It |
|---|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | The Key ID from App Store Connect | Shown on the API Keys page (e.g., `XXXXXXXXXX`) |
| `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID (UUID) from App Store Connect | Shown at the top of the API Keys page |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Base64-encoded `.p8` private key | Run: `base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy` |
| `KEYCHAIN_PASSWORD` | Password for the temporary CI keychain | Any random string: `openssl rand -hex 20` |
| `MATCH_PASSWORD` | (Optional) Encryption password for match | Only if using match for code signing |
| `MATCH_GIT_URL` | (Optional) Git URL for certificates repo | Only if using match (e.g., `git@github.com:org/certs.git`) |

## Code Signing

### Option A: Automatic Signing with API Key (Recommended for CI)

The `beta` and `release` lanes use `-allowProvisioningUpdates` with the App Store Connect API key. Xcode will automatically manage provisioning profiles. This is the simplest approach.

### Option B: Match (for teams)

If you have a team and want consistent code signing across machines:

1. Create a private Git repository for certificates
2. Run `bundle exec fastlane match init` and follow the prompts
3. Set `MATCH_GIT_URL` and `MATCH_PASSWORD` secrets
4. Run `bundle exec fastlane match_signing` to fetch certificates

## Available Lanes

| Lane | Description |
|---|---|
| `fastlane test` | Build and test iOS and watchOS targets on simulators |
| `fastlane beta` | Build, sign, and upload to TestFlight |
| `fastlane release` | Build, sign, and upload to App Store Connect |
| `fastlane match_signing` | Sync code signing via match (optional) |

## Version Bumping

Use the helper script to update version numbers in both iOS and watchOS:

```bash
# Set version to 1.2.0 with auto-incremented build number
./scripts/bump_version.sh 1.2.0

# Set version to 1.2.0 with specific build number
./scripts/bump_version.sh 1.2.0 42
```

## Troubleshooting

- **"No signing certificate" error**: Ensure your API key has Admin permissions, or use match to install certificates.
- **"No provisioning profile" error**: The API key with `-allowProvisioningUpdates` should auto-create profiles. If not, create them manually in the Apple Developer Portal.
- **Build number conflict**: The `beta` and `release` lanes auto-increment based on the latest TestFlight build. If you get a conflict, wait a few minutes for App Store Connect to process the previous build.
- **watchOS build failure**: Ensure the watchOS target's bundle ID is `com.shuttlx.ShuttlX.watchkitapp` and is registered in the Developer Portal.
