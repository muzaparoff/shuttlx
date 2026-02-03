#!/bin/bash
# =============================================================================
# bump_version.sh — Update version and build number for ShuttlX
# =============================================================================
#
# Usage:
#   ./scripts/bump_version.sh 1.2.0          # Set version to 1.2.0, auto-increment build
#   ./scripts/bump_version.sh 1.2.0 42       # Set version to 1.2.0, build number 42
#
# This script updates CFBundleShortVersionString and CFBundleVersion in both
# the iOS and watchOS Info.plist files, then optionally commits the change.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IOS_PLIST="$PROJECT_ROOT/ShuttlX/Info.plist"
WATCHOS_PLIST="$PROJECT_ROOT/ShuttlXWatch Watch App Watch App/Info.plist"

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
if [ $# -lt 1 ]; then
  echo "Usage: $0 <version> [build_number]"
  echo "  version      — Marketing version (e.g., 1.2.0)"
  echo "  build_number — Optional build number (auto-increments if omitted)"
  exit 1
fi

NEW_VERSION="$1"

# Validate version format (X.Y.Z)
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Error: Version must be in X.Y.Z format (e.g., 1.2.0)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Determine build number
# ---------------------------------------------------------------------------
if [ $# -ge 2 ]; then
  NEW_BUILD="$2"
else
  # Read current build number from iOS Info.plist and increment
  CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$IOS_PLIST" 2>/dev/null || echo "0")
  NEW_BUILD=$((CURRENT_BUILD + 1))
fi

echo "=== ShuttlX Version Bump ==="
echo "  Version:      $NEW_VERSION"
echo "  Build Number: $NEW_BUILD"
echo ""

# ---------------------------------------------------------------------------
# Update iOS Info.plist
# ---------------------------------------------------------------------------
echo "Updating iOS Info.plist..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$IOS_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$IOS_PLIST"
echo "  -> $IOS_PLIST"

# ---------------------------------------------------------------------------
# Update watchOS Info.plist
# ---------------------------------------------------------------------------
echo "Updating watchOS Info.plist..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$WATCHOS_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$WATCHOS_PLIST"
echo "  -> $WATCHOS_PLIST"

echo ""
echo "Version updated successfully!"
echo ""

# ---------------------------------------------------------------------------
# Optionally commit the change
# ---------------------------------------------------------------------------
read -rp "Commit this version bump? [y/N] " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  cd "$PROJECT_ROOT"
  git add "$IOS_PLIST" "$WATCHOS_PLIST"
  git commit -m "Bump version to $NEW_VERSION (build $NEW_BUILD)"
  echo "Committed version bump."
else
  echo "Skipped commit. Don't forget to commit the changes manually."
fi
