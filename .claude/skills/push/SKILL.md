---
description: Stage all changes, auto-commit with descriptive message, push to main, monitor CI
user_invocable: true
---

# /push

Stage ALL changes, generate a commit message, push to main, and monitor CI until TestFlight.

## Steps

1. **Stage everything**:
   - Run `git add -A` to stage all modified, deleted, and untracked files
   - Run `git diff --cached --stat` to see what will be committed

2. **Auto-commit**:
   - Analyze all staged changes (diffs) to understand what changed
   - Write a short, descriptive commit message summarizing ALL changes (imperative, lowercase-start, no period)
   - If changes span multiple areas, use a summary line + bullet points in the body
   - Do NOT ask the user to confirm — just commit
   - Do NOT add a Co-Authored-By footer

3. **Push**:
   ```bash
   git push origin main
   ```

4. **Monitor CI**:
   ```bash
   gh run list --limit 1 --json databaseId,status,conclusion,name
   ```
   Then watch the run:
   ```bash
   gh run watch <run_id> --exit-status
   ```

5. **Report result**:
   - CI status: PASS or FAIL
   - If PASS: "Build uploaded to TestFlight. Allow ~15 min for App Store Connect processing."
   - If FAIL: Show failed job name and link to the run
