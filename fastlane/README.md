# fastlane/ — Store Listing Copy (+ manual lanes)

Fastlane the tool is **not** used by CI. Building, versioning (conventional-commit
auto-semver) and TestFlight upload run through the thin workflow callers of
`muzaparoff/appstore-kit@v1` in `.github/workflows/`.

This directory is kept because `metadata/` holds the App Store listing copy
(description, keywords, release notes) consumed by the kit's `store-release.yml`
workflow, alongside screenshots from `marketing/appstore/final`.

The `Fastfile` retains only manual, run-locally lanes:

| Lane | Purpose |
|---|---|
| `fastlane test` | Build/test iOS + build-verify watchOS on simulators |
| `fastlane upload_metadata` | Push `metadata/` to App Store Connect |
| `fastlane set_release_notes` | Set "What's New" for a version (`version:`, `notes:`) |
