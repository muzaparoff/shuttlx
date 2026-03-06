---
description: Push to main and monitor CI pipeline through to TestFlight
user_invocable: true
---

# /deploy

Push current branch to main and monitor the CI/CD pipeline.

## Steps

1. **Pre-flight checks**:
   - Run `git status` to confirm working tree is clean (warn if not)
   - Run `git log --oneline -3` to show what will be pushed
   - Confirm with the user before pushing

2. **Push**:
   ```bash
   git push origin main
   ```

3. **Monitor CI**:
   ```bash
   gh run list --limit 1 --json databaseId,status,conclusion,name
   ```
   Then watch the run:
   ```bash
   gh run watch <run_id> --exit-status
   ```

4. **Report result**:
   - CI status: PASS or FAIL
   - If PASS: "Build uploaded to TestFlight. Allow ~15 min for App Store Connect processing."
   - If FAIL: Show failed job name and link to the run
