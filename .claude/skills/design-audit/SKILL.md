---
description: Audit screens for theme-identity cohesion — does the UI carry the theme or just recolor stock SwiftUI?
user_invocable: true
---

# /design-audit

Visual cohesion audit. Complements `/review-changes` (token compliance): this skill judges whether screens *look designed* — theme identity, signature shapes, cross-platform cohesion.

## Usage

```
/design-audit                  # audit screens touched in current git diff
/design-audit all              # full app audit (spawns design-reviewer agent)
/design-audit <ScreenName>     # audit one screen (e.g. AnalyticsView)
```

## Steps

1. **Scope** — from args: changed view files (`git diff --name-only` filtered to `Views/`, `Components/`, `Theme/`), a named screen, or `all` (delegate to `design-reviewer` agent and stop).

2. **For each screen, score the anti-generic test** (each PASS/WARN/FAIL with file:line):

   ### Theme identity
   - [ ] Screen structure changes with theme (dispatch on `themeManager.current.id`) OR is a documented neutral surface
   - [ ] Signature shape used where the surface is themed (chart frame, progress, medal, empty state)
   - [ ] Typography uses `ShuttlXFont.*` — no raw `.font(.body)` / `.font(.headline)` / `.font(.system(size:))`
   - [ ] No hardcoded `Color.*` literals (including inside `Theme/` files)
   - [ ] Empty / loading / celebration states designed (not stock "No data" text)
   - [ ] Data viz is custom (Canvas / signature shape), not default Swift Charts styling — for themed surfaces

   ### Cross-platform cohesion (one product)
   - [ ] Watch counterpart shares visual grammar with the iOS screen for the active theme
   - [ ] Watch version respects ~180pt height budget (41mm) and max ~5 visible elements
   - [ ] No idle animations on watch outside active workout

   ### Surface classification
   - Themed surfaces: dashboard hero, analytics, summary/celebration, empty states, watch home, timer
   - Neutral surfaces (colors only, skip identity checks): forms, settings rows, sign-in, paywall, editors, maps, sheets

3. **Compare against the quality bar** — the timer heroes (`ShuttlX/Theme/Themes/*TimerHero.swift`, watch `Decorations/`). If a themed surface scores far below the timer, say so explicitly.

4. **Report**:
   - Table: screen × (identity / cohesion / states) with PASS/WARN/FAIL
   - Top 3 highest-leverage fixes with file:line and one-line direction
   - One-sentence verdict: does this change move the app toward "one original product" or add more generic surface?
