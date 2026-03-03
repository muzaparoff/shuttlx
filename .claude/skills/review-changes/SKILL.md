---
description: Review uncommitted changes against project design system and safety rules
user_invocable: true
---

# /review-changes

Review current `git diff` against ShuttlX project conventions.

## Steps

1. **Get the diff**:
   ```bash
   git diff
   git diff --cached
   ```

2. **Check each changed file** against the relevant rules:

### Design System (Views, Components, Theme)
- [ ] No hardcoded colors (`Color.red`, `Color.blue`) — use `ShuttlXColor.*` or `theme.colors.*`
- [ ] No raw font sizes (`.system(size:)`) — use `ShuttlXFont.*` or `theme.fonts.*`
- [ ] Cards use `.themedCard()` (or `.glassBackground()` for Clean-only contexts)
- [ ] No `Divider()` between list items
- [ ] Numeric displays use `.monospacedDigit()`
- [ ] Interactive elements have `.accessibilityLabel()`

### Safety (Services)
- [ ] No force unwraps (`!`) or unsafe array access (`[0]`)
- [ ] No `try?` without logging — use `do/catch` with error logging
- [ ] No `@unchecked Sendable` — use `@MainActor`
- [ ] WatchConnectivity calls check `isReachable`

### Models
- [ ] If a model was changed, BOTH copies updated (iOS + watchOS)
- [ ] New properties have default values
- [ ] Models are `Codable` + `Identifiable`

### General
- [ ] Debug code wrapped in `#if DEBUG`
- [ ] No `print()` statements — use `os.log` or `Logger`

3. **Report** a checklist with PASS/WARN/FAIL per rule, noting specific lines if violations found.
