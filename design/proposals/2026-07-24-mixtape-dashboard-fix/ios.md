# iOS hand-off — Mixtape Training screen fix

Scope: Mixtape theme, `DashboardView` idle state. Clean theme must be visually unchanged. No new palette colors — everything below is already in `MixtapeTheme.swift` or hard-wired in the scene.

## Before / After (idle, no plan, no last session)

### Before
```
  Training                         ← nav title
 ┌────────────────────────────┐
 │▐WATCH STATUS▐ (cream well)  │   StartOnWatchCard (readable — sets textPrimary)
 └────────────────────────────┘
 ┌────────────────────────────┐
 │▐THIS WEEK▐ (cream well)     │
 │  This Week          ██████  │   ← BLACK text on gunmetal (.primary fallback) — unreadable
 │  No activity yet            │   ← #8E959D chrome-dim, too low contrast
 │  ▁▁▁▁▁▁▁                    │   ← empty bars = #2E3237, invisible on #24272B
 └────────────────────────────┘
                                    ← smoke-blue cassette scene, occluded by cards
        (dark dead zone)              + wrong palette = reads as a flat slab
```

### After
```
  Training
 ╔═ brushed gunmetal chassis, chrome edge + 4 corner screws ═╗
 ┌────────────────────────────┐
 │▐WATCH STATUS▐               │   StartOnWatchCard (unchanged)
 └────────────────────────────┘
 ┌────────────────────────────┐
 │▐THIS WEEK▐  0 sessions      │   cream well header carries the title
 │  0m                         │   ← hero numeral, AMBER #FFC44D, mono
 │  no sessions logged yet     │   ← cream #EFE7D2 @ 0.85, readable
 │  ▂▁▅█▁▂▁   amber bars       │   ← filled = #FFC44D, empty = chrome tick
 │  M T W T F S S              │
 └────────────────────────────┘
 ┌──────── TAPE DECK ─────────┐
 │   ◉))))          ((((◉      │   two static amber-lit spools (signature shape)
 │   ══════ 00:00 ══════       │   tape counter, amber mono, resting
 │   STEREO · IEC TYPE II      │   chrome micro-label
 └────────────────────────────┘
```

## Fix 1 — readable `WeekSummaryCard` (`ShuttlX/Views/Dashboard/WeekSummaryCard.swift`)

- **Drop the redundant in-body title.** The `.themedCard(headerLabel: "THIS WEEK")` cream well already prints the title. Remove the `Text("This Week")` line; move the session count into the header row area or keep it as a small chrome caption. This alone kills the black-text bug and de-duplicates.
  - If the title must stay for non-Mixtape (Clean) parity, it MUST get `.foregroundStyle(ShuttlXColor.textPrimary)` — never rely on `.primary`.
- **Hero number** (`formatDuration` / `0m`): `ShuttlXColor.running` = **amber `#FFC44D`**, `ShuttlXFont.metricLarge`, `.monospacedDigit()`. This is the one expressive element on the card — the "now playing" level.
- **Empty-state line**: change copy to `no sessions logged yet`, color `ShuttlXColor.textPrimary` at ~0.85 opacity (cream `#EFE7D2`) instead of `textSecondary` chrome-dim. Cardiac-patient legibility: cream-on-gunmetal clears contrast; `#8E959D` chrome-dim does not.
- **Week bar chart — recolor as a level meter:**
  - Filled, today: `ShuttlXColor.running` amber `#FFC44D`, full opacity.
  - Filled, other days: amber `#FFC44D` at 0.45.
  - Empty day: replace the invisible `ShuttlXColor.surface` fill with a **2pt chrome baseline tick** — `ShuttlXColor.surfaceBorder` (`#C8CDD3`) at 0.5, height 3, so every day slot reads as an unrecorded tape position.
  - Today marker: swap the `ctaPrimary` (green) stroke ring for `ShuttlXColor.surfaceBorder` chrome `#C8CDD3` — green fights the amber-only "LCD" language.
  - Day letters: today `textPrimary` cream, others `textSecondary` chrome-dim (already correct).

> Note: this recolor is Mixtape-driven but the tokens (`running`, `surfaceBorder`) resolve per theme, so Clean automatically keeps its own accent — no per-theme `if` needed in the card. Verify Clean still reads correctly (Clean `running` is its accent, `surfaceBorder` its hairline — both fine).

## Fix 2 — re-skin the background scene to the Walkman palette (`ShuttlX/Theme/Components/ThemedSceneBackground.swift`)

The scene's hard-wired palette is the theme definition (per its own doc comment) and must be updated to match the refresh:

- **Shell gradient** → brushed gunmetal *lighter than the cards* so cards read as inset windows:
  - `shellTop` `#3A3E43` (bodyTop, already used by the LCD card) → `shellBottom` `#2A2D31` (one step above card base `#24272B`).
  - Cards stay `#3A3E43`→`#24272B`; keeping the chassis a touch lighter/flatter than the card gradient gives the recessed-window read. If separation is still weak in testing, drop the chassis floor to `#2A2D31` and add a 1px inner top highlight `white @0.06`.
- **Brushed-metal texture**: keep the existing horizontal mold-line Canvas but tint the lines `white @0.04` (chrome sheen) instead of the current blue-ish value.
- **Corner screws**: keep, but recolor `screwRim` → chrome `#C8CDD3`, `screwRecess` → `#3A4250`→`#2E3237`. These frame the whole screen as a face plate.
- **Reel / panel blues → gunmetal + amber**: in `staticReelThumbnail`, replace `panelBlue #1A3061`, `borderBlue`, and the blue spokes with: reel ring `#24272B`, spoke/rim `ShuttlXColor.surfaceBorder` chrome `#C8CDD3` @0.7, hub/spindle amber `#FFC44D` (a dim `@0.6` when resting). `brandText` blue `#8CADCC` → chrome `#C8CDD3 @0.5`.
- **Stop painting anatomy behind the cards.** The J-card (`h*0.28`) and hub windows (`h*0.42`) currently sit under the two cards and are wasted. For the dashboard background, suppress them (`showJCard: false, showHubs: false`, as the timer path already does) and instead expose the spools through Fix 3's explicit deck view. The chassis background then only needs: shell gradient + screws + faint brushed lines + bottom brand strip. Cleaner, cheaper, and nothing is occluded.

## Fix 3 — fill the dead zone with a resting "Tape Deck" window (new view)

- **New component** `MixtapeDeckWindow` (resting state of the signature spool shape). Place it in `DashboardView` **inside the Mixtape branch only**, after `WeekSummaryCard`, sized to eat the empty lower third (min height ~150pt, expands with a `Spacer`-backed frame so it always bottoms out above the tab bar).
- **Anatomy** (reuse `staticReelThumbnail` twice — do NOT author new spool art):
  - Dark tape window `#15171A` inset panel, `.lcdPanel()` style, chrome `#C8CDD3 @0.35` hairline border.
  - Two static spools at 0.30 / 0.70 width, amber hubs `#FFC44D @0.6`, chrome spokes — reuse `MixtapeLayoutConstants` fractions so it lines up with the timer hero's live reels.
  - Center **tape counter** `00:00`, `ShuttlXFont.metricMedium` mono, amber `#FFC44D` (dim `@0.7` = stopped). This is the resting twin of the workout timer.
  - Micro-label strip: `STEREO · IEC TYPE II` chrome `#C8CDD3 @0.5`, tracking 1.5 (reuse `brandStrip` styling).
  - A cream tape-label header `.themedCard(headerLabel: "TAPE DECK")` for framing consistency with the cards above.
- **Purpose beyond decoration**: it is the empty-state illustration for "no workout running" and doubles as an affordance — a chrome caption under it can read `▸ start on watch to roll tape` in `textSecondary`, tying the dead zone back to the primary action.

## State variants (all must be designed)

- **idle / empty** (this proposal's main case): deck stopped, counter `00:00`, spools static, week hero `0m` amber, empty ticks.
- **populated** (has sessions this week): week hero shows real amber duration, bars fill amber; deck still resting (workouts run on the watch, not here) — counter can show *last* session length in chrome-dim to feel "cued up". Optional; if not built, keep `00:00`.
- **loading** (sessions still reading off disk on resume — see recent `sessions.json` off-main-actor commit): deck spools drawn at chrome `@0.3`, counter shows `--:--`, no chart bars (skeleton). Do not flash black text.
- **error** (session decode failed): card body shows `tape unreadable` in `ctaWarning` amber-orange `#FFA318`, deck counter `E-01` — never a blank card.
- **active workout on watch**: `LiveWorkoutCard` already takes the top; the resting deck should hide (the real spinning deck lives on the timer screen) to avoid two decks. Gate `MixtapeDeckWindow` on `!sharedData.isWorkoutActiveOnWatch`.

## Accessibility / cardiac-safety notes

- Deck window is **decorative + status**: mark `.accessibilityElement(children: .ignore)` on the spool art, expose only the counter/label as one combined element (`Tape deck, stopped`).
- No idle animation on the resting spools (matches watch anti-goal + saves battery on the always-visible dashboard). Spokes/hubs are static `Canvas`, no `TimelineView`.
- Amber `#FFC44D` on gunmetal `#24272B` ≈ 8:1 contrast — clears WCAG AA large. Cream `#EFE7D2` on gunmetal ≈ 11:1. Chrome-dim `#8E959D` on gunmetal ≈ 3.4:1 — keep it for *secondary micro-labels only*, never for primary values.

## Implementation hand-off
- Files to create: `ShuttlX/Theme/Themes/Decorations/MixtapeDeckWindow.swift` (resting deck, reuses `staticReelThumbnail` + `MixtapeLayoutConstants`).
- Files to modify:
  - `ShuttlX/Views/Dashboard/WeekSummaryCard.swift` — remove redundant title, amber hero, cream empty-state, amber+chrome bars.
  - `ShuttlX/Theme/Components/ThemedSceneBackground.swift` — re-skin scene palette (shell/screws/reels/brand) to Walkman colors; suppress J-card + hubs for the dashboard background.
  - `ShuttlX/Theme/ThemeModifiers.swift` — `mixtapeBackground()` to pass `showJCard: false, showHubs: false` (mirror the existing `timerScreenBackground` call).
  - `ShuttlX/Views/DashboardView.swift` — insert `MixtapeDeckWindow` after `WeekSummaryCard`, gated on `themeManager.current.id == "mixtape" && !sharedData.isWorkoutActiveOnWatch`.
- Reuse existing: `staticReelThumbnail`, `MixtapeLayoutConstants`, `.lcdPanel()`, `.themedCard(headerLabel:)`, `brandStrip` styling, `ShuttlXColor.running/surfaceBorder/textPrimary/ctaWarning`, `ShuttlXFont.metricLarge/metricMedium`.
- Theme variants verified: only Clean + Mixtape exist (July 2026 reduction). Clean path untouched — the `WeekSummaryCard` token swaps (`running`, `surfaceBorder`) resolve to Clean's own accent/hairline; the deck window and scene re-skin are gated to `mixtape`. Confirm Clean dashboard renders identically after the `WeekSummaryCard` edits.
- Watch performance check: N/A (iOS screen). On-screen static `Canvas` only, no `TimelineView`, no idle animation on the resting deck.
- Open questions for dev:
  1. Should the "populated" deck counter show the last session's duration (cued-up feel) or stay `00:00`? Design leans cued-up but it's optional polish.
  2. `WeekSummaryCard` "This Week" title removal changes Clean's layout slightly (Clean has no cream header well — it uses `.glass`). Confirm Clean still wants an in-body title; if so, keep it but force `textPrimary`. Design defers the Clean-title decision to `senior-ios-developer`.
  3. The scene palette is hard-wired (per its doc comment) rather than pulling from `ThemeColors`. Leaving it hard-wired for now; flag if you'd rather route it through tokens so the next palette tweak is one-file.
