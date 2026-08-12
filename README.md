# ShuttlX - Complete Interval Training App

A comprehensive fitness app for iOS and watchOS featuring distance-based interval training with real-time timer countdown and GPS tracking.

## 🏃‍♂️ **Current Version: v1.3.0** (auto-versioned by CI — check `git tag` for the latest)

### ✅ **FEATURE SET**
- **🏃‍♂️ Custom Training Programs**: Create, edit, delete custom interval workouts on iOS
- **⌚ Real-Time Sync**: Programs sync to watchOS via WatchConnectivity; live metrics stream back during workouts
- **⏱️ Reliable Timer**: Drift-proof `DispatchSourceTimer` on watch — works through wrist-down and backgrounding
- **📍 GPS Tracking**: Route recording with km splits, elevation profile, and post-workout map
- **💓 HealthKit Integration**: Workout sessions, heart rate, distance, calories — with crash recovery
- **📊 Analytics**: Fitness/fatigue/form (TSB), VO2max estimate, personal records, pace zones
- **📅 Training Plans**: Built-in plans (Couch to 5K, HIIT Starter, 5K Improvement) + custom plans
- **🎨 Theme System**: 2 themes — **Clean** (default, calm glass) and **Mixtape** (Walkman cassette deck with spinning reels); reduced from 7 in July 2026, architecture still supports adding more
- **🏝️ Live Activity**: Dynamic Island + Lock Screen during workouts
- **📱 Widgets & Complications**: 4 iOS home-screen widgets + a Control Center control, 4 watch complications
- **☁️ iCloud Sync**: Sign in with Apple + CloudKit cross-device sync
- **💳 Subscriptions**: RevenueCat-backed in-app subscriptions (iOS only)
- **❓ In-App Help**: Settings → Help (`ShuttlX/Views/HelpView.swift`)

**Platforms**: iOS 18.0+ / watchOS 11.5+, SwiftUI. External SPM deps (iOS only): RevenueCat, TelemetryDeck — the watch target is Apple-frameworks-only.

## 📂 **Project Structure**
```
ShuttlX/                  # iOS app (views, services, theme system)
ShuttlX Watch App/        # watchOS app (workout engine, sync, theme mirror)
Shared/                   # ShuttlXShared SPM package (models, IntervalEngine, ...)
ShuttlXLiveActivity/      # Live Activity extension
ShuttlXWidgets/           # iOS widgets + Control
ShuttlXWatchWidgets/      # watchOS complications
tests/                    # Build/test scripts + ShuttlXTests
fastlane/                 # App Store listing copy (metadata/) + manual lanes
marketing/appstore/       # Screenshot sources + render pipeline
.github/workflows/        # Thin callers of muzaparoff/appstore-kit@v1
```

## 🛠 **BUILD & TEST**

```bash
# Build both platforms (simulator) — the canonical loop
bash tests/build_and_test_both_platforms.sh --clean --build

# Other flags: --install --test --launch --ios-only --watchos-only

# iOS only (destination only — passing -sdk breaks SPM deps of companion targets)
xcodebuild -project ShuttlX.xcodeproj -scheme ShuttlX -destination 'generic/platform=iOS Simulator' build

# watchOS only
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX Watch App" -destination 'generic/platform=watchOS Simulator' build

# Physical device build
bash tests/build_for_physical_device.sh
```

## 🚀 **CI / RELEASE PIPELINE**

CI and releases run through thin GitHub Actions callers of the shared
[`muzaparoff/appstore-kit@v1`](https://github.com/muzaparoff/appstore-kit) reusable workflows:

1. **Push to `main`** → `test.yml` runs CI and **auto-bumps the semver tag from conventional commits** (`feat:` → minor, `fix:` → patch, `BREAKING CHANGE` → major). No manual version bumping — `scripts/bump_version.sh` is gone.
2. **`v*` tag** → `deploy.yml` archives, signs, and uploads to **TestFlight**.
3. **`store-release.yml`** (manual) stages the App Store listing from `fastlane/metadata` + `marketing/appstore/final` and can submit for review.

Fastlane the tool is **not** part of CI — see `fastlane/README.md`.

## 📁 **FILE MANAGEMENT GUIDELINES**

- Work only with the actual production files — never create `_new` / `_clean` / `_backup` duplicates; use git for history.
- Models and theme files are mirrored between `ShuttlX/` and `ShuttlX Watch App/` where noted in `CLAUDE.md` — update both copies.
- Agent/contributor docs: `CLAUDE.md` (canonical), `.claude/rules/`, `docs/memory/`.
