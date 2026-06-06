# ShuttlX Project Memory

## Quick Reference
- **App**: Interval training iOS + watchOS companion app (SwiftUI, zero external deps)
- **Bundle**: `com.shuttlx.ShuttlX` / `com.shuttlx.ShuttlX.watchkitapp`
- **Team**: `83HPSY452Y`, App Group: `group.com.shuttlx.shared`
- **Targets**: iOS 18.0+, watchOS 11.5+, Live Activity extension, Widgets extension
- **Codebase**: ~13,300 LOC across 120+ Swift files (65 iOS, 38+ watchOS, 6+ extensions)
- **Storage**: JSON in App Group container (sessions.json, workout_templates.json, exercise_devices.json)
- **Sync**: WatchConnectivity (sendMessage + transferUserInfo + applicationContext)
- **CI**: GitHub Actions → App Store Connect → TestFlight (auto on push to main)

## Assets
- [App Store Screenshots](./reference_screenshots.md) — stored at `/Users/sergeymuzyukin/Desktop/ShuttlX-Screenshots/`

## Detailed Notes
- [Architecture & File Map](./architecture.md)
- [Feature Roadmap & Phases](./roadmap.md)
- [Technical Debt & Known Issues](./tech-debt.md)
- [Sync Architecture & Known Bug](./sync-architecture.md)
- [Cadence (RPM/SPM) Derivation](./cadence-derivation.md) — why CAD card was hidden, CMPedometer warmup quirk, step-delta fallback
- [Social Features & Supabase Plan](./social-backend-plan.md) — 7-phase plan for user registration, social, Supabase backend
- [Per-Theme Timer Hero Pattern](./timer-hero-pattern.md) — how 6 themes render unique hero visualizations; watch chrome overlay pattern
- [Open-Source Tooling Research](./tooling-research.md) — MCP/agent/skill landscape research (2026-06-06); curated picks in docs/proposals/tooling-additions.md

## User Preferences
- Discuss each feature before implementing — never start without explicit approval
- **Always plan first**: analyze codebase before implementing, identify affected files
- **Always update docs**: after any feature change, update CLAUDE.md, .claude/rules/, .claude/agents/, .claude/skills/, and memory files
- Dynamic multi-theme system (8 themes: Clean, Synthwave, Mixtape, Arcade, Classic Radio, VU Meter, Neovim, FM Tuner) — DONE
- Wants subscription-ready product — features need to justify payment
- Timer screen: 52pt monospaced timer, 28pt bold metrics, no emoji/icons
- Watch controls: circular buttons (green=pause, red=stop)

## Feature Status (Build 34+ / 2026-06-06)
**Done**: Core workout, intervals, Watch app, sync, analytics (VO2max/TSB/PRs), training plans (3 built-in), themes (8 incl. FM Tuner), per-theme timer heroes (6 themes with unique hero visualizations on both platforms), Live Activity, widgets (2 iOS + 3 Watch), maps/routes, CloudKit + Sign In (basic), onboarding, settings, iOS Free Run card, exercise devices (6 built-in + custom), MET-based calorie estimation, large session sync fix, BPM visibility in walk/run, pace rolling-window fix, cadence step-delta fallback
**Partial**: Multi-sport (model only), custom fonts (not bundled)
**Not done**: Voice coaching, export/sharing, StoreKit subscriptions, social groups/challenges, auto-pause, pace/HR alerts, user profile + public CloudKit

## Theme System (IMPLEMENTED — 8 themes with per-theme heroes)
- `@Observable ThemeManager` singleton, `selectTheme(id)` for switching, stored `current` property
- `ShuttlXColor`/`ShuttlXFont` bridge enums — all code is theme-aware
- 16 files mirrored per target under `Theme/` (now includes per-theme hero files: SynthwaveHero, MixtapeHero, ArcadeHero, ClassicRadioHero, VUMeterHero, NeovimHero)
- **Screen backgrounds**: `.themedScreenBackground()` modifier on all major views — each theme has unique full-screen background
  - Clean: `MeshGradient` (iOS) / `LinearGradient` fallback (watchOS) — soft indigo/blue/purple
  - Synthwave: Canvas-drawn horizon grid with perspective lines + sun glow + Outrun speedometer hero
  - Mixtape: blue player body + horizontal texture lines + blue sheen gradient + spinning cassette reels hero
  - Arcade: CRT scanlines + radial vignette + phosphor green tint + 7-segment HI-SCORE hero
  - Classic Radio: warm dark brown + subtle grain texture + brown vignette + tuning dial with sweeping needle hero
  - VU Meter: dark warm base + horizontal amber panel lines + amber radial glow + dual vertical gauge needles hero
  - Neovim: Gruvbox Dark #1D2021 solid + left gutter stripe (iOS) / solid (watchOS) + command-line status line hero
  - FM Tuner: #021018 solid + FMTunerHeader chrome overlay + FMTunerVUColumn overlay (Canvas, 18 segments)
- `ThemeEffects` CardStyle: `.glass`, `.neon`, `.lcd`, `.pixel`, `.tape`, `.meter`, `.terminal` (Neovim), `.lcd` (shared by Mixtape and FM Tuner)
- `MeshGradient` is iOS-only — watchOS uses `LinearGradient` fallback for Clean theme
- Remaining: custom fonts for some themes

## Lessons Learned
- `@Observable` only tracks **stored** properties — computed don't trigger updates
- `didSet` + `@Observable` can interfere — prefer explicit methods
- Always verify theme changes end-to-end on device, not just compilation
- `MeshGradient` is iOS 18+ only — NOT available on watchOS. Use `LinearGradient` fallback on watch
- CMPedometer distance has ~30s warmup lag + skewed first sample (pedometer-only). Sliding window + early-workout guards fix pace lockup at 10'00
- Free-run watch layout has ~180pt budget for metrics (41mm screen). Full-size rows overflow; compact two-up rows fit 5+ metrics
- Per-theme hero dispatch is simple: iOS switch on `themeManager.current.id`; watch uses `if id == "<name>"` blocks placed as non-hittable overlays in the ZStack

## MCP Servers
- `xcodebuildmcp` — Xcode build integration
- `mcp-image` (Nano Banana / shinpr/mcp-image) — image generation via Gemini, 3 quality presets
- `svgmaker` (@genwave/svgmaker-mcp) — SVG vector generation (needs SVGMAKER_API_KEY)

## Build Commands
```bash
# Both platforms
bash tests/build_and_test_both_platforms.sh --clean --build
# iOS only
xcodebuild -project ShuttlX.xcodeproj -scheme ShuttlX -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
# watchOS only
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX Watch App" -sdk watchsimulator -destination 'generic/platform=watchOS Simulator' build
```

## Current Build
- On TestFlight: Build 34+ — per-theme timer heroes, BPM visibility fix, pace rolling-window fix, cadence step-delta fallback
- Previous: Build 33 (iOS Free Run card, Watch home redesign, theme system)
