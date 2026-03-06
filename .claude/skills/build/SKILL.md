---
description: Build, boot simulators, pair, install, and launch both iOS and watchOS targets
user_invocable: true
---

# /build

Full local dev flow: boot simulators, pair watch↔phone, build both platforms, install apps, and launch them.

## Steps

1. Run the full build + install + launch script:
   ```bash
   bash tests/build_and_test_both_platforms.sh --clean --build --install --launch
   ```

   This will:
   - Boot iPhone 17 Pro + Apple Watch Series 11 (46mm) simulators
   - Pair watch↔phone if not already paired
   - Open Simulator.app
   - Clean build both platforms
   - Install apps on both simulators
   - Launch apps on both simulators

2. Parse the output and report:
   - Simulators: booted/paired status
   - iOS build: PASS or FAIL (with first error if failed)
   - watchOS build: PASS or FAIL (with first error if failed)
   - Install: success or failure per platform
   - Launch: success or failure per platform

3. If either target fails to build, show the first 3 error lines to help diagnose.

4. Format the result as a concise summary table.
