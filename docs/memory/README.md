# Project Memory (Snapshot)

These markdown files are a **version-controlled snapshot** of the Claude Code auto-memory for this project. They are checked into the repository so:

- Team agents spawned in a fresh clone start with full project context
- New contributors (human or AI) can read the current state without a prior session
- The memory is reviewable in pull requests like any other doc

## Two sources of truth (by design)

| Location | Purpose | Who writes |
|----------|---------|-----------|
| `~/.claude/projects/-Users-sergeymuzyukin-github-shuttlx/memory/` | Live auto-memory, updated by Claude Code during sessions | Claude (auto) |
| `docs/memory/` (this dir) | Periodic snapshot for sharing + git history | Lead at end of feature work |

**Snapshot policy:** the lead agent runs `/sync-memory` (or copies manually) at the end of each feature sprint, just before pushing the docs-keeper commit. This is intentionally non-automatic so noisy mid-session edits don't churn git history.

## What's in here

- `MEMORY.md` — top-level index (always loaded into Claude's context for this project)
- `architecture.md` — file map + targets + module layout
- `roadmap.md` — feature phases + status
- `tech-debt.md` — known issues + workarounds
- `sync-architecture.md` — WatchConnectivity flow + the historical sync bug
- `cadence-derivation.md` — CMPedometer warmup quirk + step-delta fallback fix
- `social-backend-plan.md` — Supabase 7-phase plan
- `reference_screenshots.md` — pointer to App Store screenshot assets

## How agents read this

Agents spawned by `project-manager` are prompted with the path to this directory so they pick up shared context without re-discovering it from code. See `.claude/agents/project-manager.md` for the orchestration rules.

## Sync command

To refresh the snapshot from live memory:

```bash
cp ~/.claude/projects/-Users-sergeymuzyukin-github-shuttlx/memory/*.md docs/memory/
git add docs/memory/ && git commit -m "chore(memory): snapshot $(date +%Y-%m-%d)"
```
