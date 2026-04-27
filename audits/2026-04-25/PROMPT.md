# ShuttlX Audit + Recovery Feature Spike — 2026-04-25

This is an AUDIT and DESIGN-ONLY run. Do not modify source code.
Produce findings and specs only.

Spawn the following 8 sub-agents IN PARALLEL via the Task tool in a
SINGLE message (multiple Task tool calls in one message run concurrently):
  swift-architect, swiftui-watchos-specialist, healthkit-domain-expert,
  performance-engineer, ux-ui-designer, accessibility-auditor,
  security-privacy-reviewer, recovery-feature-architect

Each writes its report to its assigned path under audits/2026-04-25/
or specs/2026-04-25/.

Every audit finding must include:
- Severity: P0 / P1 / P2 / P3
- File:line reference (agents must actually open files)
- Why it matters in one sentence
- Suggested fix direction (approach, not full code)
- Confidence: high / medium / low

Quality over quantity. If an agent has under 5 findings, say so —
do not pad.

After all 8 agents complete, run a 9th synthesis pass yourself:
read every report, then write audits/2026-04-25/00-SYNTHESIS.md with:
- Top 10 P0/P1 issues ranked by impact x confidence x fix-cost^-1
- Cross-cutting themes (issues found by 2+ agents — these are real)
- Conflicts between agents (flag for human triage)
- Three fix-batches: this week / this sprint / backlog
- Total estimated effort in dev-days
- Integration plan: how the recovery-feature spec should sequence
  against the audit fixes (which audit issues block the new feature)

Output discipline: markdown only, no emoji, no speculation without
reading the file, code refs as Path/File.swift:42.

Begin now. Spawn all 8 in parallel.
