#!/bin/bash

# Setup watchOS Target for ShuttlX
# This script guides you through adding a watchOS target to the existing iOS project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_step() {
    echo -e "${YELLOW}[STEP]${NC} $1"
}

clear
echo "🍎 ShuttlX watchOS Target Setup"
echo "==============================="
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo_error "Xcode is not installed or xcodebuild is not available"
    exit 1
fi

echo_success "Xcode detected"

# Check if project exists
if [ ! -d "ShuttlX.xcodeproj" ]; then
    echo_error "ShuttlX.xcodeproj not found in current directory"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo_success "ShuttlX.xcodeproj found"

# Check if watchOS code exists
if [ ! -d "WatchApp" ]; then
    echo_error "WatchApp directory not found"
    echo "The watchOS app code should be in a WatchApp/ directory"
    exit 1
fi

echo_success "WatchApp code directory found"

echo ""
echo_step "Step 1: We'll open Xcode to add the watchOS target"
echo ""
echo "We need to add a watchOS target to your Xcode project. This requires using Xcode's interface."
echo "Here's what we'll do:"
echo ""
echo "1. Open your project in Xcode"
echo "2. Guide you through adding a watchOS App target"
echo "3. Configure the target with your existing watchOS code"
echo "4. Update build scripts for dual-platform development"
echo ""

read -p "Press Enter to open Xcode..."

# Open Xcode project
echo_status "Opening Xcode project..."
open ShuttlX.xcodeproj

echo ""
echo_step "Step 2: Add watchOS Target in Xcode"
echo ""
echo "Now follow these steps in Xcode:"
echo ""
echo "1. In Xcode, select your project in the navigator (top-level 'ShuttlX')"
echo "2. Click the '+' button at the bottom of the targets list"
echo "3. Choose 'watchOS' → 'Watch App'"
echo "4. Click 'Next'"
echo "5. Configure the target:"
echo "   - Product Name: ShuttlXWatch"
echo "   - Bundle Identifier: com.shuttlx.watch (or your preferred identifier)"
echo "   - Language: Swift"
echo "   - Interface: SwiftUI"
echo "   - Include Notification Scene: YES (recommended)"
echo "6. Click 'Finish'"
echo "7. Xcode will create a basic watchOS app structure"
echo ""

read -p "Have you completed adding the watchOS target? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo_warning "Please complete the watchOS target setup in Xcode first"
    exit 1
fi

echo_success "watchOS target added!"

echo ""
echo_step "Step 3: Replace generated files with our existing watchOS code"
echo ""

# Check if the watchOS target was created
if [ ! -d "ShuttlXWatch" ]; then
    echo_warning "ShuttlXWatch directory not found. It should have been created by Xcode."
    echo "Please make sure you named the target 'ShuttlXWatch' or update this script with the correct name."
    read -p "What did you name the watchOS target? " WATCH_TARGET_NAME
    if [ ! -d "$WATCH_TARGET_NAME" ]; then
        echo_error "Directory '$WATCH_TARGET_NAME' not found"
        exit 1
    fi
    WATCH_DIR="$WATCH_TARGET_NAME"
else
    WATCH_DIR="ShuttlXWatch"
fi

echo_status "Found watchOS target directory: $WATCH_DIR"

# Backup the generated files
echo_status "Backing up generated files..."
if [ -d "${WATCH_DIR}_backup" ]; then
    rm -rf "${WATCH_DIR}_backup"
fi
cp -r "$WATCH_DIR" "${WATCH_DIR}_backup"

echo_success "Generated files backed up to ${WATCH_DIR}_backup"

# Copy our watchOS app files
echo_status "Copying our watchOS app files..."

# Copy the main app files
cp WatchApp/ShuttlXWatchApp.swift "$WATCH_DIR/"
cp WatchApp/WatchWorkoutManager.swift "$WATCH_DIR/"
cp WatchApp/WatchConnectivityManager.swift "$WATCH_DIR/"

# Copy Views directory
if [ -d "$WATCH_DIR/Views" ]; then
    rm -rf "$WATCH_DIR/Views"
fi
cp -r WatchApp/Views "$WATCH_DIR/"

echo_success "watchOS app files copied"

echo ""
echo_step "Step 4: Update Xcode project with our files"
echo ""
echo "Now we need to add our files to the Xcode project:"
echo ""
echo "1. In Xcode, right-click on the '$WATCH_DIR' group in the navigator"
echo "2. Choose 'Add Files to \"ShuttlX\"...'"
echo "3. Navigate to the '$WATCH_DIR' directory"
echo "4. Select all the .swift files we just copied:"
echo "   - ShuttlXWatchApp.swift"
echo "   - WatchWorkoutManager.swift" 
echo "   - WatchConnectivityManager.swift"
echo "   - Views folder (with all its contents)"
echo "5. Make sure 'Target Membership' includes only the watchOS target"
echo "6. Click 'Add'"
echo "7. Remove the generated ContentView.swift and any other generated files you don't need"
echo ""

read -p "Have you added our watchOS files to the Xcode project? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo_warning "Please add the watchOS files to the Xcode project"
    exit 1
fi

echo ""
echo_step "Step 5: Configure watchOS target settings"
echo ""
echo "Configure the watchOS target in Xcode:"
echo ""
echo "1. Select the watchOS target in the project navigator"
echo "2. Go to 'Signing & Capabilities'"
echo "3. Enable 'HealthKit'"
echo "4. Go to 'Info' tab"
echo "5. Add 'Privacy - Health Share Usage Description' and 'Privacy - Health Update Usage Description'"
echo "6. Set deployment target to watchOS 9.0 or later"
echo ""

read -p "Have you configured the watchOS target settings? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo_warning "Please configure the watchOS target settings"
    exit 1
fi

echo ""
echo_step "Step 6: Test the setup"
echo ""

echo_status "Testing iOS build..."
if xcodebuild -project ShuttlX.xcodeproj -scheme ShuttlX -destination 'platform=iOS Simulator,name=iPhone 16' build; then
    echo_success "iOS build successful!"
else
    echo_error "iOS build failed"
    exit 1
fi

echo_status "Testing watchOS build..."
WATCH_SCHEME_NAME=$(xcodebuild -project ShuttlX.xcodeproj -list | grep -A 10 "Schemes:" | grep -i watch | head -1 | xargs)
if [ -z "$WATCH_SCHEME_NAME" ]; then
    echo_warning "Could not find watchOS scheme automatically"
    echo "Available schemes:"
    xcodebuild -project ShuttlX.xcodeproj -list | grep -A 20 "Schemes:"
    read -p "Please enter the watchOS scheme name: " WATCH_SCHEME_NAME
fi

echo_status "Using watchOS scheme: $WATCH_SCHEME_NAME"

if xcodebuild -project ShuttlX.xcodeproj -scheme "$WATCH_SCHEME_NAME" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build; then
    echo_success "watchOS build successful!"
else
    echo_error "watchOS build failed"
    echo "This might be due to missing dependencies or configuration issues"
    echo "Please check the build errors in Xcode"
fi

echo ""
echo_success "🎉 watchOS target setup complete!"
echo ""
echo "Next steps:"
echo "1. Run './build_and_test_both_platforms.sh' to test both platforms together"
echo "2. Use Xcode to pair iPhone and Watch simulators"
echo "3. Test WatchConnectivity between the apps"
echo ""
echo "If you encounter issues:"
echo "- Check build errors in Xcode"
echo "- Make sure all files are added to the correct targets"
echo "- Verify HealthKit permissions are configured"
echo "- Check that WatchConnectivity is properly set up"
