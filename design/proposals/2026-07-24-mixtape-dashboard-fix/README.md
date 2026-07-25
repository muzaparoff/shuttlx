# Mixtape Training screen fix — Walkman face plate

**Surface:** iOS Training / home (`ShuttlX/Views/DashboardView.swift`) with the Mixtape theme, idle state (no active workout, no active plan, no last session) — i.e. the "empty" dashboard a new user or a returning-after-a-gap user sees.

**Theme context:** Mixtape just got the "Walkman hardware" palette refresh — gunmetal body `#24272B`, amber LCD `#FFC44D`, cream tape-label headers `#EFE7D2`, play-green `#3ECF6D`, brushed chrome `#C8CDD3`. The dashboard did not follow: it reads as a dark slab with black/unreadable card text and no Walkman identity.

## The three reported breakages (root cause)

1. **Unreadable card body text.**
   `WeekSummaryCard` draws its title `Text("This Week")` with **no `.foregroundStyle`** (line 39–40), so it falls back to SwiftUI `.primary` = **black in light appearance** on the dark `#24272B` gunmetal card body. The "No activity yet" line uses `textSecondary` (`#8E959D` chrome-dim) which is technically set but too low-contrast on gunmetal. The empty-day chart bars use `ShuttlXColor.surface` (`#2E3237`) — 1 shade off the card body, effectively invisible. There is also a **redundant title**: the `.themedCard(headerLabel: "THIS WEEK")` cream well already prints "THIS WEEK", then the body repeats "This Week".

2. **Invisible background / no Walkman identity.**
   `mixtapeBackground()` renders `MixtapeCassetteScene`, but that scene's palette was **never updated in the Walkman refresh** — it is still hard-wired to the old smoke-blue shell (`shellTop #26303F` → `shellBottom #161E29`), blue brand text `#8CADCC`, and blue reel panels. Smoke-blue on top of gunmetal cards reads as one flat dark mass. Worse, the scene paints its cassette anatomy (J-card at `h*0.28`, hubs at `h*0.42`) **directly behind the two stacked cards**, so the only identity elements are occluded; what's left visible is just dark shell edge.

3. **Dead zone below the cards.**
   Idle dashboard shows only `StartOnWatchCard` + `WeekSummaryCard` — two short cards at the top, then ~40% of the screen empty. The cassette scene was meant to fill it but is invisible (issue 2), so it reads as wasted dark space.

## Design strategy — turn the whole screen into the Walkman face plate

One move fixes 2 and 3 together and reinforces the theme's signature shape (cassette spool):

- **Re-skin the background as the player chassis, not a cassette.** The background is the *brushed-gunmetal deck face* the cards are inset into — lighter than the cards so the cards read as recessed windows. Then relocate the **cassette-spool signature shape** out from *behind* the cards into the *empty lower third* as a resting "tape deck window". Dead zone becomes the identity anchor.
- **Resting deck ↔ spinning deck continuity.** The lower deck window shows two static amber-lit spools + a `00:00` tape counter when idle. This is the same object the timer hero spins during a workout — the dashboard is the deck at rest, the workout is the deck playing. One parametric spool `Canvas`, two states.
- **Cards = LCD level readouts.** Fix the text contrast and switch the week bar chart from play-green to **amber LCD**, so the card reads like a graphic-EQ / VU strip on the deck rather than a generic bar chart.

This keeps Clean untouched (its calm cardiac baseline), touches only the Mixtape code paths, and uses only palette colors already defined.

## References
- Signature-shape DNA + themed-surface rules: `.claude/rules/design-system.md`
- Existing spool renderer to reuse/reskin: `MixtapeCassetteScene.staticReelThumbnail` in `ShuttlX/Theme/Components/ThemedSceneBackground.swift`
- Timer-hero continuity: `MixtapeTimerHero` (`ShuttlX/Theme/Themes/Decorations/MixtapeTimerHero.swift`)
- Competitor idle-state benchmark: Apple Fitness "no activity" rings + Gentler Streak rest-day framing both keep an *identity object* on screen when data is empty rather than going blank — the deck window plays that role here.
