---
name: Open-Source Tooling Research (2026-06-06)
description: Full research on open-source MCP servers, agents, skills, and frameworks relevant to ShuttlX's iOS + watchOS solo-dev stack
type: reference
---

# Open-Source Tooling Research — 2026-06-06

Conducted by `claude-code-guide` agent. **Source of truth for the curated short list in `docs/proposals/tooling-additions.md`.** This doc is the full investigation; the proposal is the cherry-picked recommendation.

## Categories investigated

1. MCP servers for iOS / Swift / Apple platforms
2. Design automation MCPs
3. QA automation
4. Open-source Claude Code agent collections
5. Skills + slash commands

## Key findings (summary)

### Build / simulator
- **getsentry/XcodeBuildMCP** — Sentry-maintained successor to the original. Already in our `mcp` config per memory.
- **joshuayoes/ios-simulator-mcp** — UI automation via Facebook IDB. Best fit for `qa-engineer` agent to actually drive a simulator.

### App Store Connect / release
- Multiple ASC MCP implementations exist — pick by recent commit + star count.
- `crasowas/app_privacy_manifest_fixer` (or similar) — important for ShuttlX given RevenueCat + TelemetryDeck + HealthKit declarations.

### HealthKit testing
- **StanfordBDHG/XCTHealthKit** — clean SPM library for mocking HealthKit samples in unit tests. Perfect for `test-author` agent + cardiac-rehab features.

### Design
- **Figma MCP** (official) — only useful if we use Figma. We don't.
- **SF Symbols MCP** — Xcode built-in is sufficient.

### E2E testing
- **Maestro MCP** — strong YAML E2E framework with watchOS support. Defer until there's an E2E backlog to automate; would otherwise be net-new work.

### Community agent collections
- `VoltAgent/awesome-claude-code-subagents` — large curated set, including Swift specialist.
- `rohitg00/awesome-claude-code-toolkit` — comprehensive.
- `vijaythecoder/awesome-claude-agents` — team orchestration patterns.
- `hesreallyhim/awesome-claude-code` — meta-collection.
- Recommendation: skim VoltAgent for prompt improvements to `senior-ios-developer` + `swiftui-watchos-specialist`.

## Pre-install verification protocol

Before adopting any of these:
1. `gh repo view <owner/repo>` — confirm repo exists and was updated recently
2. Read the README for install steps — do NOT trust the snippets in this doc blindly
3. For MCP servers: sandbox a single tool before adding to `~/.claude/mcp.json`
4. For SPM: check transitive dependencies

## Why this matters for future sessions

When a future Claude session reads this and thinks "should we add Maestro/Figma/etc?", the answer is in this doc:
- Maestro: defer (no E2E backlog to automate)
- Figma: skip (project doesn't use Figma)
- XCTHealthKit: yes, when writing HRR/segmenter tests
- ios-simulator-mcp: yes, when expanding `qa-engineer`
- ASC MCP: yes, after picking the best-maintained variant

## Constraints reminder

- Solo developer, no team
- Minimal external dependencies (RevenueCat + TelemetryDeck only)
- Health data / cardiac rehab — App Store compliance is critical
- Already shipped: xcodebuildmcp, mcp-image, svgmaker, GitHub Actions → TestFlight pipeline, custom `/push`, `/build`, `/deploy`, `/review-changes`, `/payment-check` skills
