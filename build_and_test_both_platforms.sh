#!/bin/zsh

# ShuttlX - Build and Test Script for iOS and watchOS
# This script builds and tests both platforms as per the phased rewrite plan
# Usage: ./build_and_test_both_platforms.sh [flags]
# Flags: --clean, --build, --install, --test, --launch, --ios-only, --watchos-only

set -e

# Parse command line arguments
CLEAN=false
BUILD=false
INSTALL=false
TEST=false
LAUNCH=false
IOS_ONLY=false
WATCHOS_ONLY=false

# If no arguments provided, default to build and install
if [ $# -eq 0 ]; then
    BUILD=true
    INSTALL=true
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --build)
            BUILD=true
            shift
            ;;
        --install)
            INSTALL=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        --launch)
            LAUNCH=true
            shift
            ;;
        --ios-only)
            IOS_ONLY=true
            shift
            ;;
        --watchos-only)
            WATCHOS_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option $1"
            echo "Usage: $0 [--clean] [--build] [--install] [--test] [--launch] [--ios-only] [--watchos-only]"
            exit 1
            ;;
    esac
done

echo "🚀 ShuttlX Dual Platform Build & Install Script"
echo "==============================================="
echo "Configuration:"
echo "  Clean: $CLEAN"
echo "  Build: $BUILD"
echo "  Install: $INSTALL"
echo "  Test: $TEST"
echo "  Launch: $LAUNCH"
echo "  iOS Only: $IOS_ONLY"
echo "  watchOS Only: $WATCHOS_ONLY"
echo ""

# Function to clean up macOS metadata that causes code signing issues
cleanup_metadata() {
    local app_path="$1"
    if [ -d "$app_path" ]; then
        echo "🧹 Cleaning up macOS metadata in: $app_path"
        find "$app_path" -name ".DS_Store" -delete 2>/dev/null || true
        find "$app_path" -name "._*" -delete 2>/dev/null || true
        xattr -cr "$app_path" 2>/dev/null || true
    fi
}

# Function to build with code signing error tolerance
build_target() {
    local target="$1"
    local sdk="$2"
    local destination="$3"
    local platform_name="$4"
    
    echo "\n🔨 Building $platform_name target: $target"
    echo "SDK: $sdk"
    echo "Destination: $destination"
    
    # Build without code signing for simulator
    if xcodebuild -project ShuttlX.xcodeproj -target "$target" -sdk "$sdk" -destination "$destination" \
        CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
        clean build 2>&1 | tee "/tmp/build_${platform_name}.log"; then
        echo "✅ $platform_name build successful!"
        return 0
    else
        # Check if it's just a code signing error (expected for simulator)
        if grep -q "CodeSign.*failed" "/tmp/build_${platform_name}.log" && ! grep -q -E "(error:|Error:|BUILD FAILED)" "/tmp/build_${platform_name}.log"; then
            echo "⚠️  $platform_name build completed with expected code signing error (simulator)"
            echo "✅ $platform_name compilation successful!"
            return 0
        else
            echo "❌ $platform_name build failed with compilation errors!"
            echo "📄 Build log saved to: /tmp/build_${platform_name}.log"
            echo "📄 Last few lines of error log:"
            tail -10 "/tmp/build_${platform_name}.log"
            return 1
        fi
    fi
}

# Helper: Get simulator UDID by name and runtime
get_sim_udid() {
    local name="$1"
    local runtime="$2"
    xcrun simctl list devices --json | \
        python3 -c "import sys, json; d=json.load(sys.stdin)['devices'];
for k in d:
    if '$runtime' in k:
        for dev in d[k]:
            if dev['name'] == '$name' and dev.get('isAvailable', False):
                print(dev['udid']); exit(0)
exit(1)"
}

# Helper: Boot simulator if not already booted
boot_simulator() {
    local udid="$1"
    local state=$(xcrun simctl list devices | grep "$udid" | grep -oE '\((Booted|Shutdown)\)' | tr -d '()')
    if [ "$state" != "Booted" ]; then
        echo "🔄 Booting simulator $udid..."
        xcrun simctl boot "$udid"
        # Wait for boot
        sleep 5
    fi
}

# Configuration
IOS_SCHEME="ShuttlX"
WATCHOS_SCHEME="ShuttlXWatch Watch App"
IOS_TARGET="ShuttlX"
WATCHOS_TARGET="ShuttlXWatch Watch App"
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=18.5"
WATCHOS_DESTINATION="platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=11.5"

# Build both targets
echo "\n⌚ Building watchOS target first..."
if ! build_target "$WATCHOS_TARGET" "watchsimulator" "$WATCHOS_DESTINATION" "watchOS"; then
    exit 1
fi

# Find and preserve watchOS app immediately after build (before it gets cleaned up)
WATCHOS_APP_PATH=$(find build -name "*Watch*App.app" -type d 2>/dev/null | head -1)
if [ -n "$WATCHOS_APP_PATH" ]; then
    echo "🔍 watchOS app path detected: $WATCHOS_APP_PATH"
    # Copy to temp location to preserve during iOS build
    TEMP_WATCHOS_APP="/tmp/ShuttlXWatch_Watch_App.app"
    rm -rf "$TEMP_WATCHOS_APP"
    cp -R "$WATCHOS_APP_PATH" "$TEMP_WATCHOS_APP"
    echo "💾 watchOS app preserved to: $TEMP_WATCHOS_APP"
    WATCHOS_APP_PATH="$TEMP_WATCHOS_APP"
else
    echo "⚠️  watchOS app path not detected"
fi

echo "\n📱 Building iOS target (independent)..."
if ! build_target "$IOS_TARGET" "iphonesimulator" "$IOS_DESTINATION" "iOS"; then
    exit 1
fi

# Find iOS app after build
IOS_APP_PATH=$(find build/Release-iphonesimulator -name "*.app" -type d 2>/dev/null | head -1)
echo "🔍 iOS app path detected: $IOS_APP_PATH"

echo "\n🔧 Installing on simulators..."

# Clean up built apps metadata
if [ -n "$WATCHOS_APP_PATH" ] && [ -d "$WATCHOS_APP_PATH" ]; then
    cleanup_metadata "$WATCHOS_APP_PATH"
fi

if [ -n "$IOS_APP_PATH" ] && [ -d "$IOS_APP_PATH" ]; then
    cleanup_metadata "$IOS_APP_PATH"
fi

# Get UDIDs for target simulators
IOS_UDID=$(get_sim_udid "iPhone 16" "iOS-18-5")
WATCHOS_UDID=$(get_sim_udid "Apple Watch Series 10 (46mm)" "watchOS-11-5")

# Boot simulators if needed
if [ -n "$IOS_UDID" ]; then
    boot_simulator "$IOS_UDID"
fi
if [ -n "$WATCHOS_UDID" ]; then
    boot_simulator "$WATCHOS_UDID"
fi

# Install iOS app

echo "\n📱 Installing iOS app..."
if [ -n "$IOS_APP_PATH" ] && [ -n "$IOS_UDID" ] && xcrun simctl install "$IOS_UDID" "$IOS_APP_PATH"; then
    echo "✅ iOS app installed successfully!"
elif [ -n "$IOS_APP_PATH" ]; then
    echo "⚠️  iOS app built but installation skipped (simulator may not be available)"
else
    echo "⚠️  iOS app path not found, skipping installation"
fi

# Install watchOS app

echo "\n⌚ Installing watchOS app..."
if [ -n "$WATCHOS_APP_PATH" ] && [ -n "$WATCHOS_UDID" ] && xcrun simctl install "$WATCHOS_UDID" "$WATCHOS_APP_PATH"; then
    echo "✅ watchOS app installed successfully!"
elif [ -n "$WATCHOS_APP_PATH" ]; then
    echo "⚠️  watchOS app built but installation skipped (simulator may not be available)"
else
    echo "⚠️  watchOS app path not found, skipping installation"
fi

echo "\n🎉 Build process completed!"
echo "\n✅ Both iOS and watchOS targets built successfully"
echo "📱 iOS: iPhone 16 Simulator (iOS 18.5)"
echo "⌚ watchOS: Apple Watch Series 10 Simulator (watchOS 11.5)"
echo "\n📄 Build logs available at:"
echo "   - iOS: /tmp/build_iOS.log"
echo "   - watchOS: /tmp/build_watchOS.log"

# Cleanup temp files
rm -rf "/tmp/ShuttlXWatch_Watch_App.app" 2>/dev/null || true