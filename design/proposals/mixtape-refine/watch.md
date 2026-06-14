# Mixtape Refine — watchOS hand-off spec

Secondary doc. Owner: `swiftui-watchos-specialist`.
Scope files: `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift`
(`MixtapeWatchDeck`, `MixtapeReelBadge`), `ShuttlX Watch App/Views/TrainingView.swift`
(L645–680), `ShuttlX Watch App/Views/RecoveryWorkoutView.swift` (L186–267).

Same direction as `ios.md`, **free-run first**, but smaller surface — do not
over-invest. The ~180pt 41/42mm height budget is hard; never let chrome push HR or
the hero number off-screen. Build: `xcodebuild ... -scheme "ShuttlX Watch App" ...`.

## Layout (unchanged structure, refined) — `MixtapeWatchDeck` L135–147

```
[SIDE A] ●  MORNING RUN          PAUSED   ← J-card strip (no rotation, italic)
 ╭──╮   ┌────────────┐   ╭──╮              ← twin reels (differential) + LCD window
│░░│   │  12:34      │   │██│              ← hero number, sublabel, 5pt tape bar
 ╰──╯   │  ELAPSED    │   ╰──╯
        └────────────┘
 HR        142  BPM  [Z3]                  ← zone-colored, full width (keep)
 DIST 4.12      PACE 5'48                  ← compact two-up (keep)
```

---

## P1 — Safety + trademark (blocking)

### P1-B — Zone color remap (CARDIAC SAFETY)
Watch reads zone color via `ShuttlXColor.forHRZone(bpm)` (`MixtapeWatchDeck` L281,
L290; `MixtapeReelBadge` n/a). The fix lives in the **iOS+watch mirrored**
`MixtapeTheme.swift` token values — see `ios.md` P1-B. **The watch theme file is a
mirror and must be updated to identical values:**
```
hrZone1: #1C8009 (0.11,0.50,0.04)   hrZone2: #39FF14 (0.22,1.00,0.08)
hrZone3: #F2A61A (0.95,0.65,0.10)   hrZone4: #FF6A1A (1.00,0.42,0.10)
hrZone5: #FF3333 (1.00,0.20,0.20)
```
> Coordinate with `senior-ios-developer` so both copies stay identical (models/theme
> dual-target rule). No `MixtapeWatchDeck` call-site change — tokens only.

### Trademark scrub (visible UI + a11y + struct names) — BLOCKING
- `TrainingView.swift` L645 comment "Mixtape Controls (Walkman transport keys)" →
  "cassette transport keys"; L647 comment "Walkman keys" → "cassette keys";
  **L680 accessibilityHint "Walkman play key" → "Play key"**.
- `RecoveryWorkoutView.swift`: rename `struct WalkmanRecoveryKeyStyle`
  → **`CassetteRecoveryKeyStyle`** (declaration L267, usage L208, comment L260);
  L186 doc comment "chunky Walkman" → "chunky cassette key".
- Decoration file `MixtapeTimerHero.swift` L5 comment "Mixtape Walkman timer chrome"
  → "Mixtape cassette timer chrome".
- If `MixtapeWatchDeck` has a "SIDE A" / brand strip elsewhere, ensure no
  BASF/TYPE II literals (none found in current deck — verify).

### P1-C — PAUSED chip solid amber
`MixtapeWatchDeck` `jCardStrip` L175–183: the chip is a stroke-only outline (≈ low
contrast on cream). Make it **solid `amberPause` fill with `labelInk` text** (mirror
iOS P1-C). Keep `cornerRadius: 3`.

---

## P2 — Authenticity / safety

### P2-E — Reel spin slower (vestibular + battery) — SAFETY
Current spin = `elapsedTime * 0.25 * 360 = 90°/s` (`MixtapeWatchDeck` L133,
`MixtapeReelBadge` L47). 90°/s on a tiny watch reel is fast/flickery for older eyes
and burns battery. Slow to **~30°/s**: `elapsedTime * 0.0833 * 360`
(≈ 1 rev / 12s). Update BOTH the deck (L133) and the badge (L47) to match.

### P1-1 (lite) — Differential reels on watch
Apply a **lighter** version of the iOS differential fill: supply `scaleEffect
1.0→0.7`, take-up `0.7→1.0` over `tapeProgress` (free-run: elapsed/3600; interval:
stepIndex/total). `MixtapeWatchDeck.reel(direction:)` L210–220. RPM coupling is
optional on watch (battery) — fixed slow spin (P2-E) is fine; the **size change** is
the cheap, high-impact cue. Skip glass glare / sheen on watch (battery + space).

### P2-A — Sublabel contrast
`MixtapeWatchDeck` `compact` labels + `heroSubLabel` use `textSecondary` (#8CADCC) /
`lcdGreenDim` on dark — verify each ≥ 4.5:1 against its actual background. The
`heroSubLabel` `lcdGreenDim` on `lcdWell` (#051405-ish) is borderline; bump to
`lcdGreen.opacity(0.8)` when not paused (L235). DIST/PACE labels at `textSecondary`
on the shell are OK; the **values** stay `lcdGreen` (good).

---

## P3 — Polish

### P3-D — Pause haptic
On pause/resume the cassette keys should "clunk." The transport buttons already use
`SensoryFeedback` via the shared style; ensure the **pause action** in
`TrainingView` (L645–680 control block) triggers `.sensoryFeedback(.impact(weight:
.medium), trigger: workoutManager.isPaused)` so a pause without a visible key press
(e.g. crown/auto) still gives the tactile "stop" cue. Cardiac-safety nicety:
unambiguous confirmation the tape stopped.

### Tape progress bar 3pt → 5pt
`MixtapeWatchDeck.tapeProgressBar` L265: `.frame(height: 3)` → **5** for glanceability
(it doubles as the differential-fill cue's confirmation). Add the iOS P3-1
"nearly-done" tint (`ledRed.opacity(0.5)` remaining track past ~0.85) if it fits.

### SIDE A COMPLETE / parked reel
On the COMPLETE summary, `MixtapeParkedReel` (L70) parks at progress 1.0 — make the
parked reel render at the **take-up grown / supply shrunk** sizes for consistency
with the new differential fill (tape wound to end of side A).

---

## State coverage
- **ACTIVE:** twin reels spin ~30°/s + differential size, LCD green, REC red.
- **PAUSED:** reels frozen, amber LCD + name, solid amber PAUSED chip, pause haptic.
- **COMPLETE:** parked reels (supply thin / take-up fat), summary via existing path.
- **No-data HR:** "—" bpm, no Z badge (existing L278/287).

---

## Implementation hand-off
- **Files to create:** none.
- **Files to modify:**
  - `ShuttlX Watch App/Theme/Themes/MixtapeTheme.swift` (P1-B zone tokens — mirror
    iOS; keep BOTH copies identical per dual-target rule)
  - `ShuttlX Watch App/Theme/Themes/Decorations/MixtapeTimerHero.swift`
    (`MixtapeWatchDeck`: P1-C chip L175–183, P2-E spin L133, P1-1-lite reels
    L210–220, P2-A sublabel L235, tape bar L265, parked reel L70; `MixtapeReelBadge`
    spin L47; comment scrub L5)
  - `ShuttlX Watch App/Views/TrainingView.swift` (trademark comments L645/647 +
    a11y hint L680; P3-D pause haptic)
  - `ShuttlX Watch App/Views/RecoveryWorkoutView.swift` (rename
    `WalkmanRecoveryKeyStyle` → `CassetteRecoveryKeyStyle` L208/260/267, comment L186)
- **Reuse existing:** `ShuttlXColor.forHRZone()`; `MixtapeReel` asset; existing
  `SensoryFeedback` via the shared transport style; `MixtapeParkedReel`.
- **Theme variants verified:** all changes are Mixtape-scoped (`id == "mixtape"`
  paths, Mixtape decoration file, Mixtape theme tokens, Mixtape-only recovery
  keycap) — no impact on the other 7 watch themes. MeshGradient/Clean unaffected.
- **Open questions for dev:**
  1. P1-1-lite: does `scaleEffect` on the small watch reel image stay crisp at 0.7×,
     or does it need `.interpolation(.high)` retune? Verify on 41mm.
  2. P2-E: confirm ~30°/s reads as "alive but calm" on device vs 90°/s — tune live.
  3. P1-B tokens MUST land in the same PR/commit as the iOS copy to avoid divergence
     — coordinate sequencing with the lead.
</content>
