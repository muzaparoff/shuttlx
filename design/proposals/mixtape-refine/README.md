# Mixtape Theme — Refine & Complete (2026-06-13)

Skeuomorphic cassette-tape visual style for the active-workout timer screens.
This proposal makes the existing Mixtape theme **more beautiful, more authentic,
more complete, and safe** — it does NOT remove the cassette aesthetic.

> Devs: skip to `ios.md` (primary) and `watch.md`. This README is rationale only.

## Priority weighting (from the user)

1. **iOS Free Run timer is the #1 priority** — most design energy here.
2. iOS views > watch.
3. Interval mode + watch are secondary — covered, not over-invested.

## The vision: "a finished physical object"

The current Mixtape deck reads as a *retro skin*. The goal is to make it read as a
**real cassette you are watching play in a window** — a tangible object with
differential reel fill, glass glare, head-contact felt, hinge screws, and a real
tape-counter module. Two signature touches set it apart from generic retro skins:

- **Signature touch #1 — Differential reel fill (the headline authenticity win).**
  Real cassettes: the **supply** reel starts fat and shrinks; the **take-up** reel
  starts thin and grows; angular velocity rises as a reel's radius shrinks
  (ω ∝ 1/radius). Today both reels are the same image at the same rate spinning
  opposite directions — physically wrong and the #1 thing breaking the illusion.
  We drive reel **size + RPM** from a `tapeProgress` 0→1 scalar. As a free run
  goes on, you literally watch the tape wind from the left reel onto the right.
  Nobody else's retro fitness skin does this.

- **Signature touch #2 — The moving tape sheen + glass glare.** A single fixed
  diagonal specular streak across the hub-window "glass" (clear polycarbonate),
  plus a slow horizontal sheen that travels across the tape-window strip once per
  ~6s while running (paused: static). Sells "there is real glass and real moving
  tape behind it" without competing with any live metric (low opacity, behind
  numbers, `.allowsHitTesting(false)`, disabled under Reduce Motion / Low Power).

## Reviewer findings being incorporated

Two reviews already done — this proposal builds on them, does not re-audit:

- **Design-reviewer (craft/authenticity):** differential reels (P1-1), hub/scene
  alignment (P1-2), hub inset lighting (P2-1), J-card laid-paper texture (P2-2),
  window vs panel material differentiation (P2-3), keycap dome/specular (P2-4),
  leader-tape progress nod (P3-1), authentic LCD touches (P3-4), trademark
  scrub, Dynamic Island safe-area (H3).
- **UX / cardiac-safety reviewer (these are SAFETY — never traded for chrome):**
  Z1/Z2 same green (P1-B), PAUSED chip near-invisible (P1-C), BPM too small for
  free run (P1-D), pace unreadable as a needle (P1-E), distance/steps contrast
  (P2-B), name rotation overlap (P2-G), REC dot / SIDE-A-COMPLETE / finish polish
  (P3-B/C/G), STOP-vs-CANCEL keycap differentiation (P3-F).

## Hard constraints (carried into every spec)

- **NO Sony / Walkman / BASF / TDK / Maxell / "TYPE II" literal trademark** in
  visible UI, accessibility hints, OR internal struct/style names. Generic
  cassette vocabulary only: SIDE A/B, PLAY, STOP, REC, COUNTER, IEC TYPE II,
  HIGH BIAS, C-90.
- **Cardiac-rehab-adjacent.** HR + zone, time, pace, distance legibility is
  paramount and is never sacrificed to chrome. Clean stays the calm baseline; this
  theme must stay safe too.

## Reuse map

- `ClassicRadioTimerFrame` (`ShuttlX/Theme/ThemeAssets.swift` ~L390, brushed-metal
  horizontal-line Canvas ~L517) is the reference pattern for the J-card laid-paper
  Canvas — copy its lined-Canvas approach, don't reinvent.
- `ShuttlXColor.forHRZone(bpm)` already exists — reuse for zone color; the fix is
  in the **theme token values** (`MixtapeTheme.swift` L28–32), not the call sites.
- `MixtapeReel` image asset — keep; the differential fill is a SwiftUI
  `scaleEffect` on the existing image + a Canvas oxide ring, not a new asset.

## Mood / palette anchor (unchanged tokens, documented here for devs)

| Token | Hex | Role |
|---|---|---|
| shellTop | #26303F | smoke-blue ABS top |
| shellBottom | #161E29 | ABS bottom |
| labelPaper | #EDE7D3 | J-card cream |
| labelInk | #1C2330 | J-card ink |
| feltPad | #B8453A | head-contact felt red |
| lcdGreen | #39FF14 | LCD pixel lit |
| lcdGreenDim | #1C8009 (0.11,0.50,0.04) | LCD pixel dim |
| accentBlue | #4A8ACA | blue accent / SPD needle |
| ledRed | #FF3333 | REC / zone 5 |
| amberPause | #F2A61A | PAUSE / zone transition |

## Open questions (for the lead / devs to resolve)

- See per-platform "Open questions for dev" in `ios.md` and `watch.md`.
</content>
</invoke>
