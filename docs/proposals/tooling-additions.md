# Proposed Open-Source Tooling Additions

Researched 2026-06-06 by `claude-code-guide` agent. Curated picks below — full research preserved in `docs/memory/tooling-research.md`.

## Rationale

ShuttlX is solo-dev, dual-target (iOS + watchOS), minimal-dependency, health-data sensitive. Any new tooling must:
1. Be **opt-in** (no required runtime deps in production)
2. Be **read-mostly** or **dev-only**
3. Save real time vs. existing scripts
4. Have a clear maintainer (not dead code)

## Top 5 picks (recommended)

### 1. **XCTHealthKit** (Stanford Biodesign) — HealthKit unit testing

- **Repo:** https://github.com/StanfordBDHG/XCTHealthKit
- **What:** SPM library for mocking HealthKit data in XCTest. Lets you write tests that assert "given a workout with these HR samples, the segmenter produces N HRR captures" without touching a real device or Health app.
- **Why ShuttlX:** Cardiac rehab features (recovery segmenter, HRR captures, HR zones) are perfect candidates for unit tests but currently require manual device validation. This unblocks the `test-author` agent to write real coverage.
- **Install:**
  ```swift
  // tests/Package.swift or test target's Package dependencies
  .package(url: "https://github.com/StanfordBDHG/XCTHealthKit.git", from: "1.0.0")
  ```
- **Risk:** Test-only dependency, no production impact. Stanford BDHG actively maintains it.
- **Effort to adopt:** ~½ day to write the first 5 HRR-capture tests.

### 2. **ios-simulator-mcp** (Joshua Yoes) — UI automation MCP

- **Repo:** https://github.com/joshuayoes/ios-simulator-mcp
- **What:** MCP server wrapping Facebook's `idb` for simulator tap / swipe / screenshot / element inspection.
- **Why ShuttlX:** Closes the gap the `qa-engineer` agent has — currently it does static review because it can't actually drive a simulator. With this MCP, QA can tap through the workout flow and screenshot regressions.
- **Install:**
  ```bash
  pipx install fb-idb   # prereq
  # Add to ~/.claude/mcp.json:
  # "ios-simulator": { "command": "npx", "args": ["-y", "ios-simulator-mcp"] }
  ```
- **Risk:** Active maintenance — verify ≥ recent commit before installing. Local-only, zero production impact.
- **Effort to adopt:** ~1h install + 1 trial flow with qa-engineer.

### 3. **App Store Connect MCP** — release ops automation

- **What:** MCP servers exist for the ASC API (search "app-store-connect-mcp" — multiple impls, evaluate before picking). Equivalent to a programmable version of what `/payment-check` already does.
- **Why ShuttlX:** `release-shepherd` agent could check TestFlight build status, review notes, crash rate post-launch without you opening App Store Connect.
- **Install:** Reuses your existing ASC API key (`~/.appstoreconnect/private_keys/AuthKey_6QQCAX76A3.p8`). MCP config in `~/.claude/mcp.json`.
- **Risk:** Pick the most-starred / most-recent implementation — multiple competing forks exist.
- **Effort to adopt:** ~30 min once the right repo is chosen.

### 4. **Privacy Manifest Fixer**

- **Repo:** Search "app_privacy_manifest_fixer" — shell-based scanner that diffs your `PrivacyInfo.xcprivacy` against actual API usage.
- **Why ShuttlX:** RevenueCat + TelemetryDeck + HealthKit + Live Activity = lots of declared APIs. A missing reason string in the manifest blocks App Store review for health-data apps. This catches it pre-submission.
- **Install:** Clone + run as a pre-push hook or as a CI step.
- **Risk:** Audits first, reports diffs — doesn't auto-rewrite without confirmation.
- **Effort to adopt:** ~30 min, run once per release.

### 5. **VoltAgent/awesome-claude-code-subagents** (reference fork)

- **What:** Large community-curated collection of `.claude/agents/*.md` definitions, including iOS / Swift specialists.
- **Why ShuttlX:** Sanity-check our 22 existing agent definitions against community best practices. Specifically interesting: their "swift-expert" and "ios-architect" definitions may have prompts we can borrow for our `senior-ios-developer` / `senior-architect`.
- **Install:** Reference only — clone, diff against our agents, cherry-pick prompt improvements.
- **Risk:** Zero (read-only research)
- **Effort:** ~1h to skim and identify improvements.

## Explicitly NOT recommended

| Tool | Reason to skip |
|------|----------------|
| Figma MCP | Project doesn't use Figma — designs are produced inline by `product-designer` agent into `design/proposals/` |
| SF Symbols MCP | Xcode's built-in Symbol Browser + `Image(systemName:)` autocompletion is sufficient |
| CloudKit `cktool` | Already in Xcode 12+ as command-line tool; no new install needed |
| Maestro | Great YAML E2E framework, but ShuttlX has no E2E test suite today — adding Maestro would be net-new work, not an automation of existing work. Defer until there's a test backlog to automate. |
| Xcode Build Optimization Agent | Modifies `.pbxproj` — too risky for solo-dev with no second pair of eyes. Manual review of build phases preferred. |

## Verification before installing

Before adding ANY of these to `~/.claude/mcp.json` or your `Package.swift`:

1. **Verify the GitHub repo exists and was updated in the last 90 days** (`gh repo view <slug>`)
2. **Read the install command from the README** — don't trust the snippets above blindly; this proposal was written from research that may have hallucinated URLs
3. **For MCP servers:** install in a sandbox / try a single tool before adding to `mcp.json` permanently
4. **For SPM dependencies:** check the package's transitive dependencies — XCTHealthKit may pull in unwanted Stanford packages

## Recommended adoption order

1. **Now**: XCTHealthKit (test target only, lowest risk, highest value for cardiac-rehab features)
2. **Next sprint**: ios-simulator-mcp (unlocks real QA automation)
3. **Before next App Store release**: Privacy Manifest Fixer (compliance)
4. **Optional, on demand**: App Store Connect MCP, VoltAgent fork for agent prompt improvements

## What I will NOT do without explicit approval

- Add anything to `~/.claude/mcp.json` (your machine config)
- Add anything to `~/.claude/settings.json`
- Add SPM dependencies to the project — even test-only
- Install Homebrew packages or pipx packages

All five picks above need an explicit "yes, install X" from you. This doc just gathers the options.
