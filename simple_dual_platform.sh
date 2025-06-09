#!/bin/bash

# Simple Hardcoded Dual Platform Automation
# iPhone 16 (iOS 18.4) + Apple Watch Series 10 (watchOS 11.5)

set -e

echo "🚀 ShuttlX Hardcoded Automation"
echo "📱 iPhone 16 (iOS 18.4)"
echo "⌚ Apple Watch Series 10 46mm (watchOS 11.5)"
echo ""

# Configuration
PROJECT_PATH="ShuttlX.xcodeproj"
IOS_SCHEME="ShuttlX"

# Hardcoded device identifiers (we'll find the right ones)
IOS_TARGET_NAME="iPhone 16"
WATCH_TARGET_NAME="Apple Watch Series 10 (46mm)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to find device ID by name
find_device_id() {
    local device_name="$1"
    local device_id=$(xcrun simctl list devices | grep "$device_name" | head -1 | grep -E -o '\([A-F0-9-]+\)' | tr -d '()')
    echo "$device_id"
}

# Function to boot device
boot_device() {
    local device_id="$1"
    local device_name="$2"
    
    if [ -z "$device_id" ]; then
        echo_error "Device ID not found for $device_name"
        return 1
    fi
    
    local state=$(xcrun simctl list devices | grep "$device_id" | grep -o "(Booted)\|(Shutdown)")
    
    if [ "$state" != "(Booted)" ]; then
        echo_info "Booting $device_name..."
        xcrun simctl boot "$device_id"
        sleep 3
    fi
    
    echo_success "$device_name is ready"
}

# Function to build iOS
build_ios() {
    echo_info "Building iOS app for iPhone 16..."
    
    local ios_device_id=$(find_device_id "$IOS_TARGET_NAME")
    
    if [ -z "$ios_device_id" ]; then
        echo_error "iPhone 16 simulator not found"
        echo "Available iOS devices:"
        xcrun simctl list devices | grep iPhone
        return 1
    fi
    
    echo_info "Using iOS device: $ios_device_id"
    
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$IOS_SCHEME" \
        -destination "platform=iOS Simulator,id=$ios_device_id" \
        -configuration Debug \
        clean build
    
    if [ $? -eq 0 ]; then
        echo_success "iOS build completed successfully"
        return 0
    else
        echo_error "iOS build failed"
        return 1
    fi
}

# Function to build watchOS (if target exists)
build_watchos() {
    echo_info "Checking for watchOS target..."
    
    # Check if watchOS scheme exists
    local watch_schemes=$(xcodebuild -project "$PROJECT_PATH" -list | grep -i watch || true)
    
    if [ -z "$watch_schemes" ]; then
        echo_error "No watchOS scheme found"
        echo "Available schemes:"
        xcodebuild -project "$PROJECT_PATH" -list | grep -A 10 "Schemes:"
        echo ""
        echo "Please run './setup_watchos_target.sh' to add watchOS support"
        return 1
    fi
    
    # Use the first watch scheme found
    local watch_scheme=$(echo "$watch_schemes" | head -1 | xargs)
    echo_info "Found watchOS scheme: $watch_scheme"
    
    local watch_device_id=$(find_device_id "$WATCH_TARGET_NAME")
    
    if [ -z "$watch_device_id" ]; then
        echo_error "Apple Watch Series 10 simulator not found"
        echo "Available watchOS devices:"
        xcrun simctl list devices | grep "Apple Watch"
        return 1
    fi
    
    echo_info "Using watchOS device: $watch_device_id"
    
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$watch_scheme" \
        -destination "platform=watchOS Simulator,id=$watch_device_id" \
        -configuration Debug \
        clean build
    
    if [ $? -eq 0 ]; then
        echo_success "watchOS build completed successfully"
        return 0
    else
        echo_error "watchOS build failed"
        return 1
    fi
}

# Function to install and launch iOS
install_ios() {
    echo_info "Installing and launching iOS app..."
    
    local ios_device_id=$(find_device_id "$IOS_TARGET_NAME")
    boot_device "$ios_device_id" "$IOS_TARGET_NAME"
    
    # Find app bundle
    local app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "ShuttlX.app" -path "*/Debug-iphonesimulator/*" | head -1)
    
    if [ -z "$app_path" ]; then
        echo_error "iOS app bundle not found. Make sure build was successful."
        return 1
    fi
    
    echo_info "Installing from: $app_path"
    xcrun simctl install "$ios_device_id" "$app_path"
    
    if [ $? -eq 0 ]; then
        echo_success "iOS app installed"
        xcrun simctl launch "$ios_device_id" "com.shuttlx.ShuttlX" || echo_info "App installed, launch manually if needed"
    else
        echo_error "Failed to install iOS app"
        return 1
    fi
}

# Function to open simulators
open_simulators() {
    echo_info "Opening simulators..."
    
    local ios_device_id=$(find_device_id "$IOS_TARGET_NAME")
    local watch_device_id=$(find_device_id "$WATCH_TARGET_NAME")
    
    boot_device "$ios_device_id" "$IOS_TARGET_NAME"
    boot_device "$watch_device_id" "$WATCH_TARGET_NAME"
    
    # Open Simulator app
    open -a Simulator
    
    echo_success "Both simulators opened"
}

# Main execution
case "${1:-build-ios}" in
    "build-ios")
        build_ios
        ;;
    "build-watchos")
        build_watchos
        ;;
    "build-all")
        echo_info "Building both platforms..."
        if build_ios; then
            echo_success "iOS build OK"
        fi
        if build_watchos; then
            echo_success "watchOS build OK"
        fi
        ;;
    "install-ios")
        install_ios
        ;;
    "open-sims")
        open_simulators
        ;;
    "full")
        echo_info "Full automation sequence..."
        if build_ios; then
            open_simulators
            sleep 2
            install_ios
            echo_success "🎉 iOS automation complete!"
        else
            echo_error "iOS build failed"
        fi
        ;;
    "help")
        echo "Commands:"
        echo "  build-ios     Build iOS for iPhone 16"
        echo "  build-watchos Build watchOS for Apple Watch Series 10"
        echo "  build-all     Build both platforms"
        echo "  install-ios   Install and launch iOS app"
        echo "  open-sims     Open both simulators"
        echo "  full          Complete automation"
        ;;
    *)
        echo "Use 'help' to see available commands"
        ;;
esac
