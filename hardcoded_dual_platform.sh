#!/bin/bash

# Hardcoded Dual Platform Build & Install Script
# iPhone 16 (iOS 18.4) + Apple Watch Series 10 46mm (watchOS 11.5)

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

clear
echo "🚀 ShuttlX Hardcoded Dual Platform Automation"
echo "=============================================="
echo "📱 Target: iPhone 16 (iOS 18.4)"
echo "⌚ Target: Apple Watch Series 10 46mm (watchOS 11.5)"
echo ""

# Hardcoded Configuration
PROJECT_PATH="ShuttlX.xcodeproj"
IOS_SCHEME="ShuttlX"
WATCH_SCHEME="ShuttlXWatch"  # Will be created when watchOS target is added

# Specific simulator targets
IOS_DEVICE_NAME="iPhone 16"
IOS_RUNTIME="iOS 18.4"
WATCH_DEVICE_NAME="Apple Watch Series 10 (46mm)"
WATCH_RUNTIME="watchOS 11.5"

# Bundle identifiers (update these to match your project)
IOS_BUNDLE_ID="com.shuttlx.ShuttlX"
WATCH_BUNDLE_ID="com.shuttlx.ShuttlX.watchkitapp"

# Function to find specific device with runtime
find_device_with_runtime() {
    local device_name="$1"
    local runtime="$2"
    
    # Get the runtime identifier
    local runtime_id=$(xcrun simctl list runtimes | grep "$runtime" | awk -F' - ' '{print $2}' | head -1)
    
    if [ -z "$runtime_id" ]; then
        echo_error "Runtime '$runtime' not found"
        return 1
    fi
    
    echo_status "Looking for '$device_name' with runtime '$runtime' ($runtime_id)"
    
    # Find device with specific runtime
    local device_id=$(xcrun simctl list devices | grep "$runtime" -A 20 | grep "$device_name" | head -1 | grep -E -o '\([A-F0-9-]+\)' | tr -d '()')
    
    if [ -z "$device_id" ]; then
        echo_warning "Device '$device_name' with '$runtime' not found, creating..."
        
        # Create the device
        device_id=$(xcrun simctl create "ShuttlX-$device_name-${runtime// /.}" "com.apple.CoreSimulator.SimDeviceType.$(echo "$device_name" | tr ' ' '-')" "$runtime_id")
        
        if [ $? -eq 0 ]; then
            echo_success "Created device: $device_id"
        else
            echo_error "Failed to create device"
            return 1
        fi
    fi
    
    echo "$device_id"
}

# Function to boot simulator if not running
boot_simulator() {
    local device_id="$1"
    local device_name="$2"
    
    local sim_state=$(xcrun simctl list devices | grep "$device_id" | grep -o "(Booted)\|(Shutdown)")
    
    if [ "$sim_state" = "(Shutdown)" ] || [ -z "$sim_state" ]; then
        echo_status "Booting $device_name..."
        xcrun simctl boot "$device_id"
        sleep 5
        echo_success "$device_name booted"
    else
        echo_success "$device_name already running"
    fi
}

# Function to clean build iOS
clean_build_ios() {
    echo_status "Clean building iOS app for iPhone 16 (iOS 18.4)..."
    
    local ios_device_id=$(find_device_with_runtime "$IOS_DEVICE_NAME" "$IOS_RUNTIME")
    if [ -z "$ios_device_id" ]; then
        echo_error "Failed to find/create iOS device"
        return 1
    fi
    
    echo_status "Using iOS device: $ios_device_id"
    
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$IOS_SCHEME" \
        -destination "platform=iOS Simulator,id=$ios_device_id" \
        -configuration Debug \
        clean build \
        | grep -E "(CLEAN|BUILD|SUCCEEDED|FAILED|error:|warning:)" || true
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo_success "iOS clean build completed successfully"
        return 0
    else
        echo_error "iOS clean build failed"
        return 1
    fi
}

# Function to clean build watchOS  
clean_build_watchos() {
    echo_status "Clean building watchOS app for Apple Watch Series 10 (watchOS 11.5)..."
    
    # Check if watchOS scheme exists
    if ! xcodebuild -project "$PROJECT_PATH" -list | grep -q "$WATCH_SCHEME"; then
        echo_warning "watchOS scheme '$WATCH_SCHEME' not found"
        echo "Available schemes:"
        xcodebuild -project "$PROJECT_PATH" -list | grep -A 10 "Schemes:"
        echo ""
        echo "Please run './setup_watchos_target.sh' first to add watchOS target"
        return 1
    fi
    
    local watch_device_id=$(find_device_with_runtime "$WATCH_DEVICE_NAME" "$WATCH_RUNTIME")
    if [ -z "$watch_device_id" ]; then
        echo_error "Failed to find/create watchOS device"
        return 1
    fi
    
    echo_status "Using watchOS device: $watch_device_id"
    
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$WATCH_SCHEME" \
        -destination "platform=watchOS Simulator,id=$watch_device_id" \
        -configuration Debug \
        clean build \
        | grep -E "(CLEAN|BUILD|SUCCEEDED|FAILED|error:|warning:)" || true
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo_success "watchOS clean build completed successfully"
        return 0
    else
        echo_error "watchOS clean build failed"
        return 1
    fi
}

# Function to install and launch iOS app
install_launch_ios() {
    echo_status "Installing and launching iOS app..."
    
    local ios_device_id=$(find_device_with_runtime "$IOS_DEVICE_NAME" "$IOS_RUNTIME")
    boot_simulator "$ios_device_id" "$IOS_DEVICE_NAME"
    
    # Find the app bundle
    local app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "ShuttlX.app" -path "*/Debug-iphonesimulator/*" | head -1)
    
    if [ -z "$app_path" ]; then
        echo_error "Could not find iOS app bundle. Make sure build was successful."
        return 1
    fi
    
    echo_status "Installing app from: $app_path"
    
    # Install the app
    xcrun simctl install "$ios_device_id" "$app_path"
    
    if [ $? -eq 0 ]; then
        echo_success "iOS app installed successfully"
        
        # Launch the app
        xcrun simctl launch "$ios_device_id" "$IOS_BUNDLE_ID"
        
        if [ $? -eq 0 ]; then
            echo_success "iOS app launched successfully"
            echo_status "iOS Device ID: $ios_device_id"
        else
            echo_warning "App installed but failed to launch. You can launch manually."
        fi
    else
        echo_error "Failed to install iOS app"
        return 1
    fi
}

# Function to install and launch watchOS app
install_launch_watchos() {
    echo_status "Installing and launching watchOS app..."
    
    local watch_device_id=$(find_device_with_runtime "$WATCH_DEVICE_NAME" "$WATCH_RUNTIME")
    boot_simulator "$watch_device_id" "$WATCH_DEVICE_NAME"
    
    # Find the watch app bundle
    local watch_app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*watchOS*" -path "*/Debug-watchsimulator/*" | head -1)
    
    if [ -z "$watch_app_path" ]; then
        echo_warning "Could not find watchOS app bundle. This might be normal if watchOS target isn't set up yet."
        return 1
    fi
    
    echo_status "Installing watch app from: $watch_app_path"
    
    # Install the watch app
    xcrun simctl install "$watch_device_id" "$watch_app_path"
    
    if [ $? -eq 0 ]; then
        echo_success "watchOS app installed successfully"
        
        # Launch the watch app
        xcrun simctl launch "$watch_device_id" "$WATCH_BUNDLE_ID"
        
        if [ $? -eq 0 ]; then
            echo_success "watchOS app launched successfully"
            echo_status "watchOS Device ID: $watch_device_id"
        else
            echo_warning "Watch app installed but failed to launch. You can launch manually."
        fi
    else
        echo_error "Failed to install watchOS app"
        return 1
    fi
}

# Function to pair iPhone and Watch simulators
setup_pairing() {
    echo_status "Setting up iPhone-Watch pairing..."
    
    local ios_device_id=$(find_device_with_runtime "$IOS_DEVICE_NAME" "$IOS_RUNTIME")
    local watch_device_id=$(find_device_with_runtime "$WATCH_DEVICE_NAME" "$WATCH_RUNTIME")
    
    # Boot both simulators
    boot_simulator "$ios_device_id" "$IOS_DEVICE_NAME"
    boot_simulator "$watch_device_id" "$WATCH_DEVICE_NAME"
    
    # Try to pair them
    echo_status "Attempting to pair devices..."
    xcrun simctl pair "$watch_device_id" "$ios_device_id"
    
    if [ $? -eq 0 ]; then
        echo_success "Devices paired successfully"
    else
        echo_warning "Automatic pairing failed. You may need to pair manually in the Watch app."
    fi
    
    # Open Simulator app
    open -a Simulator
    
    sleep 2
    
    # Open both devices in Simulator
    xcrun simctl boot "$ios_device_id" 2>/dev/null || true
    xcrun simctl boot "$watch_device_id" 2>/dev/null || true
}

# Function to show device info
show_device_info() {
    echo ""
    echo_status "📱 Target Device Information:"
    echo "   iPhone: $IOS_DEVICE_NAME ($IOS_RUNTIME)"
    echo "   Watch:  $WATCH_DEVICE_NAME ($WATCH_RUNTIME)"
    echo ""
    
    local ios_device_id=$(find_device_with_runtime "$IOS_DEVICE_NAME" "$IOS_RUNTIME")
    local watch_device_id=$(find_device_with_runtime "$WATCH_DEVICE_NAME" "$WATCH_RUNTIME")
    
    echo_status "📱 Device IDs:"
    echo "   iOS:    $ios_device_id"
    echo "   watchOS: $watch_device_id"
    echo ""
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build-ios       Clean build iOS app only"
    echo "  build-watchos   Clean build watchOS app only"
    echo "  build-all       Clean build both platforms"
    echo "  install-ios     Install and launch iOS app"
    echo "  install-watchos Install and launch watchOS app"
    echo "  install-all     Install and launch both apps"
    echo "  setup-pair      Setup device pairing"
    echo "  show-devices    Show target device information"
    echo "  full            Complete automation: build + install + launch"
    echo "  help            Show this help message"
}

# Main execution
case "${1:-full}" in
    "build-ios")
        show_device_info
        clean_build_ios
        ;;
    "build-watchos")
        show_device_info
        clean_build_watchos
        ;;
    "build-all")
        show_device_info
        echo_status "Building both platforms..."
        ios_success=false
        watchos_success=false
        
        if clean_build_ios; then
            ios_success=true
        fi
        
        if clean_build_watchos; then
            watchos_success=true
        fi
        
        if [ "$ios_success" = true ] && [ "$watchos_success" = true ]; then
            echo_success "🎉 Both platforms built successfully!"
        elif [ "$ios_success" = true ]; then
            echo_warning "✅ iOS build succeeded, ❌ watchOS build failed"
        elif [ "$watchos_success" = true ]; then
            echo_warning "❌ iOS build failed, ✅ watchOS build succeeded"
        else
            echo_error "❌ Both builds failed"
            exit 1
        fi
        ;;
    "install-ios")
        install_launch_ios
        ;;
    "install-watchos")
        install_launch_watchos
        ;;
    "install-all")
        echo_status "Installing and launching both apps..."
        setup_pairing
        sleep 3
        install_launch_ios
        sleep 2
        install_launch_watchos
        ;;
    "setup-pair")
        setup_pairing
        ;;
    "show-devices")
        show_device_info
        ;;
    "full")
        echo_status "🚀 Running complete dual platform automation..."
        show_device_info
        
        # Build both platforms
        ios_build_success=false
        watchos_build_success=false
        
        echo_status "Step 1: Building iOS app..."
        if clean_build_ios; then
            ios_build_success=true
        fi
        
        echo_status "Step 2: Building watchOS app..."
        if clean_build_watchos; then
            watchos_build_success=true
        fi
        
        # Setup simulators and pairing
        echo_status "Step 3: Setting up simulators and pairing..."
        setup_pairing
        sleep 3
        
        # Install and launch apps
        if [ "$ios_build_success" = true ]; then
            echo_status "Step 4: Installing iOS app..."
            install_launch_ios
        fi
        
        if [ "$watchos_build_success" = true ]; then
            echo_status "Step 5: Installing watchOS app..."
            install_launch_watchos
        fi
        
        echo ""
        if [ "$ios_build_success" = true ] && [ "$watchos_build_success" = true ]; then
            echo_success "🎉 COMPLETE! Both apps built and launched successfully!"
            echo_status "📱 iPhone 16 (iOS 18.4) with ShuttlX app running"
            echo_status "⌚ Apple Watch Series 10 (watchOS 11.5) with ShuttlX app running"
            echo_status "🔗 Devices are paired and ready for WatchConnectivity testing"
        elif [ "$ios_build_success" = true ]; then
            echo_success "📱 iOS app ready! watchOS needs setup."
            echo_status "Run './setup_watchos_target.sh' to add watchOS support"
        else
            echo_error "❌ Builds failed. Check errors above."
            exit 1
        fi
        ;;
    "help"|*)
        show_usage
        ;;
esac
