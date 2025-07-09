#!/bin/bash

# build_for_physical_device.sh
# This script builds the app specifically for installation on a physical iOS device
# Author: GitHub Copilot
# Date: July 9, 2025

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Set up colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📱 ShuttlX Physical Device Build Script${NC}"
echo "========================================"

# Run preflight checks first
echo -e "${YELLOW}🔍 Running preflight checks...${NC}"

# Check for conflicting WatchKit keys in Info.plist
if [ -f "$SCRIPT_DIR/fix_watchkit_infoplist_keys.py" ]; then
    echo "  - Checking for conflicting WatchKit keys in Info.plist..."
    python3 "$SCRIPT_DIR/fix_watchkit_infoplist_keys.py"
else
    echo "  - ⚠️ Script fix_watchkit_infoplist_keys.py not found, skipping check"
fi

# Check for Info.plist resources in Copy Bundle Resources
if [ -f "$SCRIPT_DIR/remove_infoplist_from_resources.py" ]; then
    echo "  - Checking for Info.plist duplication in resources..."
    python3 "$SCRIPT_DIR/remove_infoplist_from_resources.py"
else
    echo "  - ⚠️ Script remove_infoplist_from_resources.py not found, skipping check"
fi

echo -e "${GREEN}✅ Preflight checks completed${NC}"

# Determine connected devices
echo -e "${YELLOW}🔍 Looking for connected devices...${NC}"
xcrun xctrace list devices

# Build for physical device
echo -e "${YELLOW}🔨 Building app for physical device...${NC}"
xcodebuild clean build \
    -project "${PROJECT_DIR}/ShuttlX.xcodeproj" \
    -scheme "ShuttlX" \
    -configuration Release \
    -destination generic/platform=iOS \
    CODE_SIGN_IDENTITY="Apple Development"

build_result=$?

if [ $build_result -eq 0 ]; then
    echo -e "${GREEN}✅ Build for physical device completed successfully${NC}"
    echo ""
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo "  1. Open ShuttlX.xcodeproj in Xcode"
    echo "  2. Connect your iPhone to your Mac"
    echo "  3. Select your device in the device selector"
    echo "  4. Click the Run button to install the app"
    echo ""
    echo -e "${YELLOW}Note: For successful installation, ensure:${NC}"
    echo "  - Your device is enrolled in your developer account"
    echo "  - You have a valid provisioning profile"
    echo "  - Your device is trusted on this Mac"
else
    echo -e "${RED}❌ Build failed with exit code $build_result${NC}"
fi

exit $build_result
