#!/bin/bash

# Build and Test iOS + watchOS Apps Side by Side
# This script helps you build, install, and test both iOS and watchOS apps together

set -e

# Clean up any existing log files
echo "🧹 Cleaning up old log files..."
rm -f *.log

echo "🚀 ShuttlX Multi-Platform Build & Test Script"
echo "============================================="

# HARDCODED Configuration for iPhone 16 iOS 18.4 + Apple Watch Series 10 watchOS 11.5
IOS_SCHEME="ShuttlX"
PROJECT_PATH="ShuttlX.xcodeproj"
IOS_SIMULATOR="iPhone 16"
WATCH_SIMULATOR="Apple Watch Series 10 (46mm)"

# Specific iOS/watchOS versions
IOS_VERSION="18.4"
WATCHOS_VERSION="11.5"

# Auto-detect watchOS scheme
WATCH_SCHEME=""

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

# Function to monitor logs for app startup
monitor_app_logs() {
    local device_id="$1"
    local app_name="$2"
    local duration="${3:-15}"
    
    echo_status "Monitoring $app_name logs for $duration seconds..."
    
    # Start log monitoring in background
    timeout "$duration" xcrun simctl spawn "$device_id" log stream --predicate 'processImagePath contains "ShuttlX" OR subsystem contains "shuttlx" OR messageText contains "STARTUP" OR messageText contains "WATCH-STARTUP"' --info 2>/dev/null | while read -r line; do
        if echo "$line" | grep -qE "(STARTUP|ERROR|LAUNCH|🚀|⌚)"; then
            echo_status "LOG: $line"
        fi
    done &
    
    local log_pid=$!
    sleep "$duration"
    
    # Kill the log monitoring if still running
    kill $log_pid 2>/dev/null || true
    wait $log_pid 2>/dev/null || true
    
    echo_status "Log monitoring completed"
}

# Function to detect watchOS scheme
detect_watch_scheme() {
    echo_status "Auto-detecting watchOS scheme..."
    
    local schemes=$(xcodebuild -project "$PROJECT_PATH" -list | grep -A 50 "Schemes:" | grep -v "Schemes:" | grep -v "^$" | sed 's/^[[:space:]]*//')
    
    # Check for exact scheme name "ShuttlXWatch Watch App"
    if echo "$schemes" | grep -q "ShuttlXWatch Watch App"; then
        WATCH_SCHEME="ShuttlXWatch Watch App"
        echo_success "Found watchOS scheme: $WATCH_SCHEME"
        return 0
    fi
    
    # Fallback: check for any scheme containing "Watch" or "watch"
    local watch_scheme=$(echo "$schemes" | grep -i "watch" | head -1)
    if [ -n "$watch_scheme" ]; then
        WATCH_SCHEME="$watch_scheme"
        echo_success "Found watchOS scheme: $WATCH_SCHEME"
        return 0
    fi
    
    echo_warning "No watchOS scheme found automatically"
    echo "Available schemes: $schemes"
    echo ""
    echo "If you haven't set up the watchOS target yet, run: ./setup_watchos_target.sh"
    return 0  # Don't exit, just warn
}

# Function to find device with specific iOS/watchOS version
find_device_with_version() {
    local sim_name="$1"
    local os_version="$2"
    
    echo_status "Looking for '$sim_name' with OS version '$os_version'" >&2
    
    # First, try to find exact device with the exact name and version
    local device_id=$(xcrun simctl list devices | grep -A 50 "\-\- iOS $os_version \-\-" | grep "^[[:space:]]*$sim_name (" | head -1 | grep -E -o '\([A-F0-9-]+\)' | tr -d '()')
    
    # If not iOS, try watchOS
    if [ -z "$device_id" ]; then
        device_id=$(xcrun simctl list devices | grep -A 50 "\-\- watchOS $os_version \-\-" | grep "^[[:space:]]*$sim_name (" | head -1 | grep -E -o '\([A-F0-9-]+\)' | tr -d '()')
    fi
    
    if [ -n "$device_id" ]; then
        echo_success "Found exact device: $sim_name with $os_version (ID: $device_id)" >&2
        echo "$device_id"
        return 0
    fi
    
    # If not found, try to find any device with that name (any version)
    device_id=$(xcrun simctl list devices | grep "^[[:space:]]*$sim_name (" | head -1 | grep -E -o '\([A-F0-9-]+\)' | tr -d '()')
    
    if [ -n "$device_id" ]; then
        echo_warning "Found device with different OS version, using: $device_id" >&2
        echo "$device_id"
        return 0
    fi
    
    echo_error "No device found matching '$sim_name'" >&2
    return 1
}

# Function to check if simulator is available
check_simulator() {
    local sim_name="$1"
    if xcrun simctl list devices | grep -q "$sim_name"; then
        echo_success "Simulator '$sim_name' found"
        return 0
    else
        echo_error "Simulator '$sim_name' not found"
        return 1
    fi
}

# Function to start simulator if not running
start_simulator() {
    local sim_name="$1"
    local device_id=$(xcrun simctl list devices | grep "$sim_name" | grep -E -o '\([A-F0-9-]+\)' | head -1 | tr -d '()')
    
    if [ -z "$device_id" ]; then
        echo_error "Could not find device ID for $sim_name"
        return 1
    fi
    
    local sim_state=$(xcrun simctl list devices | grep "$device_id" | grep -o "(Booted)\|(Shutdown)")
    
    if [ "$sim_state" = "(Shutdown)" ]; then
        echo_status "Starting $sim_name..."
        xcrun simctl boot "$device_id"
        sleep 3
    fi
    
    echo "$device_id"
}

# Function to build iOS app with hardcoded version
build_ios() {
    echo_status "Building iOS app for $IOS_SIMULATOR (iOS $IOS_VERSION)..."
    
    local ios_device_id
    ios_device_id=$(find_device_with_version "$IOS_SIMULATOR" "$IOS_VERSION")
    if [ -z "$ios_device_id" ]; then
        echo_error "Could not find iOS device"
        return 1
    fi
    
    echo_status "Using iOS device ID: $ios_device_id"
    
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$IOS_SCHEME" \
        -destination "platform=iOS Simulator,id=$ios_device_id" \
        -configuration Debug \
        clean build \
        | grep -E "(CLEAN|BUILD|SUCCEEDED|FAILED|error:|warning:)" || true
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo_success "iOS build completed successfully for device: $ios_device_id"
        return 0
    else
        echo_error "iOS build failed"
        return 1
    fi
}

# Function to build watchOS app with hardcoded version
build_watchos() {
    if [ -z "$WATCH_SCHEME" ]; then
        echo_warning "No watchOS scheme detected. Skipping watchOS build."
        echo "Run './setup_watchos_target.sh' to add watchOS support"
        return 1
    fi
    
    echo_status "Building watchOS app for $WATCH_SIMULATOR (watchOS $WATCHOS_VERSION)..."
    
    local watch_device_id
    watch_device_id=$(find_device_with_version "$WATCH_SIMULATOR" "$WATCHOS_VERSION")
    if [ -z "$watch_device_id" ]; then
        echo_error "Could not find watchOS device"
        return 1
    fi
    
    echo_status "Using watchOS device ID: $watch_device_id"
    
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$WATCH_SCHEME" \
        -destination "platform=watchOS Simulator,id=$watch_device_id" \
        -configuration Debug \
        clean build \
        | grep -E "(CLEAN|BUILD|SUCCEEDED|FAILED|error:|warning:)" || true
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo_success "watchOS build completed successfully for device: $watch_device_id"
        return 0
    else
        echo_error "watchOS build failed"
        return 1
    fi
}

# Function to install and launch iOS app
launch_ios() {
    echo_status "Installing and launching iOS app..."
    
    local ios_device_id
    ios_device_id=$(find_device_with_version "$IOS_SIMULATOR" "$IOS_VERSION")
    if [ -z "$ios_device_id" ]; then
        echo_error "Could not find iOS device"
        return 1
    fi
    
    # Start simulator if not running
    local sim_state=$(xcrun simctl list devices | grep "$ios_device_id" | grep -o "(Booted)\|(Shutdown)")
    if [ "$sim_state" = "(Shutdown)" ]; then
        echo_status "Starting iOS simulator..."
        xcrun simctl boot "$ios_device_id"
        sleep 5
    fi
    
    # Find iOS app bundle, excluding Index.noindex directories which contain incomplete builds
    local app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "ShuttlX.app" -path "*/Debug-iphonesimulator/*" -not -path "*/Index.noindex/*" | head -1)
    
    if [ -z "$app_path" ]; then
        echo_error "Could not find iOS app bundle in Build/Products"
        echo_status "Searching for app bundles in DerivedData (excluding Index.noindex)..."
        find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*/Debug-iphonesimulator/*" -not -path "*/Index.noindex/*" 2>/dev/null | head -5
        
        # If still not found, show what's actually there
        if [ -z "$(find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*/Debug-iphonesimulator/*" -not -path "*/Index.noindex/*" 2>/dev/null)" ]; then
            echo_status "No app bundles found in proper Build/Products location. All available bundles:"
            find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -5
        fi
        return 1
    fi

    echo_status "Found app bundle: $app_path"
    
    # Extract bundle ID from Info.plist
    local bundle_id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$app_path/Info.plist" 2>/dev/null)
    if [ -z "$bundle_id" ]; then
        echo_warning "Could not extract bundle ID from Info.plist, using default"
        bundle_id="com.shuttlx.ShuttlX"
    fi
    
    echo_status "Bundle ID: $bundle_id"
    
    # Verify app bundle has valid structure
    if [ ! -f "$app_path/Info.plist" ]; then
        echo_error "App bundle is missing Info.plist"
        return 1
    fi
    
    # Uninstall previous version if exists
    echo_status "Uninstalling previous version (if exists)..."
    xcrun simctl uninstall "$ios_device_id" "$bundle_id" 2>/dev/null || true
    
    # Install and launch with better error handling
    echo_status "Installing app..."
    if xcrun simctl install "$ios_device_id" "$app_path"; then
        echo_success "App installed successfully"
        
        echo_status "Launching app..."
        if xcrun simctl launch "$ios_device_id" "$bundle_id"; then
            echo_success "iOS app launched successfully"
            echo_status "iOS Simulator Device ID: $ios_device_id"
            
            # Wait a moment and check if app is running
            sleep 3
            echo_status "Checking app status and logs..."
            xcrun simctl spawn "$ios_device_id" log show --predicate 'subsystem contains "com.shuttlx" OR processImagePath contains "ShuttlX"' --info --last 10s 2>/dev/null | grep -E "(STARTUP|ERROR|LAUNCH)" || echo_status "No startup logs found yet"
            
        else
            echo_error "Failed to launch app"
            return 1
        fi
    else
        echo_error "Failed to install app"
        return 1
    fi
}

# Function to install and launch watchOS app
launch_watchos() {
    if [ -z "$WATCH_SCHEME" ]; then
        echo_warning "No watchOS scheme detected. Cannot launch watchOS app."
        echo "Run './setup_watchos_target.sh' to add watchOS support"
        return 1
    fi
    
    echo_status "Installing and launching watchOS app..."
    
    local watch_device_id
    watch_device_id=$(find_device_with_version "$WATCH_SIMULATOR" "$WATCHOS_VERSION")
    if [ -z "$watch_device_id" ]; then
        echo_error "Could not find watchOS device"
        return 1
    fi

    # Start simulator if not running
    local sim_state=$(xcrun simctl list devices | grep "$watch_device_id" | grep -o "(Booted)\|(Shutdown)")
    if [ "$sim_state" = "(Shutdown)" ]; then
        echo_status "Starting watchOS simulator..."
        xcrun simctl boot "$watch_device_id"
        sleep 5
    fi
    
    echo_status "Building and installing watchOS app directly..."
    
    # Use xcodebuild to install and run the app directly
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$WATCH_SCHEME" \
        -destination "platform=watchOS Simulator,id=$watch_device_id" \
        -configuration Debug \
        build install \
        | grep -E "(BUILD|INSTALL|SUCCEEDED|FAILED|error:|warning:)" || true
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo_success "watchOS app installed successfully"
        
        # Find the watch app bundle and extract bundle ID, excluding Index.noindex
        local watch_app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "*.app" -path "*/Debug-watchsimulator/*" -not -path "*/Index.noindex/*" | head -1)
        local watch_bundle_id=""
        
        if [ -n "$watch_app_path" ]; then
            watch_bundle_id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$watch_app_path/Info.plist" 2>/dev/null)
            echo_status "Found watch app at: $watch_app_path"
            echo_status "Watch Bundle ID: $watch_bundle_id"
        fi
        
        # Try to launch the app with detected bundle ID
        echo_status "Launching watchOS app..."
        if [ -n "$watch_bundle_id" ]; then
            if xcrun simctl launch "$watch_device_id" "$watch_bundle_id"; then
                echo_success "watchOS app launched successfully"
                
                # Check for logs
                sleep 3
                echo_status "Checking watch app logs..."
                xcrun simctl spawn "$watch_device_id" log show --predicate 'processImagePath contains "ShuttlX" OR subsystem contains "watch"' --info --last 10s 2>/dev/null | grep -E "(WATCH-STARTUP|ERROR|LAUNCH)" || echo_status "No watch startup logs found yet"
                
            else
                echo_warning "Could not launch watchOS app with bundle ID: $watch_bundle_id"
            fi
        else
            # Try common bundle IDs
            xcrun simctl launch "$watch_device_id" "com.shuttlx.ShuttlX.watchkitapp" || \
            xcrun simctl launch "$watch_device_id" "com.shuttlx.watch.watchkitapp" || {
                echo_warning "Could not launch watchOS app automatically"
                echo_status "App should be installed on the watch simulator. You can launch it manually."
            }
        fi
        
        echo_success "watchOS app setup completed"
        echo_status "watchOS Simulator Device ID: $watch_device_id"
        return 0
    else
        echo_error "watchOS app installation failed"
        return 1
    fi
}

# Function to create paired watch simulator (if needed)
setup_watch_pairing() {
    echo_status "Setting up Watch-iPhone pairing..."
    
    local ios_device_id=$(xcrun simctl list devices | grep "$IOS_SIMULATOR" | grep -E -o '\([A-F0-9-]+\)' | head -1 | tr -d '()')
    local watch_device_id=$(xcrun simctl list devices | grep "$WATCH_SIMULATOR" | grep -E -o '\([A-F0-9-]+\)' | head -1 | tr -d '()')
    
    if [ -z "$ios_device_id" ] || [ -z "$watch_device_id" ]; then
        echo_error "Could not find device IDs for pairing"
        return 1
    fi
    
    # Create a paired watch if it doesn't exist
    xcrun simctl pair "$watch_device_id" "$ios_device_id" 2>/dev/null || true
    
    echo_success "Watch pairing setup completed"
    echo_status "iPhone Device ID: $ios_device_id"
    echo_status "Watch Device ID: $watch_device_id"
}

# Function to show available simulators
show_simulators() {
    echo_status "Available iOS Simulators:"
    xcrun simctl list devices | grep "iPhone" | grep -v "Unavailable"
    
    echo_status "Available watchOS Simulators:"
    xcrun simctl list devices | grep "Apple Watch" | grep -v "Unavailable"
}

# Function to open both simulators
open_simulators() {
    echo_status "Opening iOS and watchOS simulators..."
    
    local ios_device_id=$(start_simulator "$IOS_SIMULATOR")
    local watch_device_id=$(start_simulator "$WATCH_SIMULATOR")
    
    # Open simulator app
    open -a Simulator
    
    echo_success "Both simulators are now running"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build-ios       Build iOS app only"
    echo "  build-watchos   Build watchOS app only"
    echo "  build-all       Build both iOS and watchOS apps"
    echo "  launch-ios      Install and launch iOS app"
    echo "  launch-watchos  Install and launch watchOS app"
    echo "  launch-both     Install and launch both apps"
    echo "  setup-watch     Setup watch pairing"
    echo "  setup-watchos   Run watchOS target setup guide"
    echo "  open-sims       Open both simulators"
    echo "  show-sims       Show available simulators"
    echo "  full            Build all, setup watch, and launch (default)"
    echo "  help            Show this help message"
}

# Auto-detect watchOS scheme at startup
detect_watch_scheme

# Main execution
case "${1:-full}" in
    "build-ios")
        build_ios
        ;;
    "build-watchos")
        build_watchos
        ;;
    "build-all")
        echo_status "Building both iOS and watchOS apps..."
        ios_success=false
        watchos_success=false
        
        if build_ios; then
            ios_success=true
        fi
        
        if build_watchos; then
            watchos_success=true
        fi
        
        if [ "$ios_success" = true ] && [ "$watchos_success" = true ]; then
            echo_success "Both platforms built successfully!"
        elif [ "$ios_success" = true ]; then
            echo_warning "iOS build succeeded, but watchOS build failed"
        elif [ "$watchos_success" = true ]; then
            echo_warning "watchOS build succeeded, but iOS build failed"
        else
            echo_error "Both builds failed"
            exit 1
        fi
        ;;
    "launch-ios")
        launch_ios
        ;;
    "launch-watchos")
        launch_watchos
        ;;
    "launch-both")
        echo_status "Launching both iOS and watchOS apps..."
        ios_launch_success=false
        watchos_launch_success=false
        
        if launch_ios; then
            ios_launch_success=true
        fi
        
        if launch_watchos; then
            watchos_launch_success=true
        fi
        
        if [ "$ios_launch_success" = true ] && [ "$watchos_launch_success" = true ]; then
            echo_success "Both apps launched successfully!"
        elif [ "$ios_launch_success" = true ]; then
            echo_warning "iOS app launched, but watchOS launch failed"
        else
            echo_error "App launch failed"
            exit 1
        fi
        ;;
    "setup-watch")
        setup_watch_pairing
        ;;
    "setup-watchos")
        echo_status "Running watchOS setup guide..."
        if [ -f "./setup_watchos_target.sh" ]; then
            ./setup_watchos_target.sh
        else
            echo_error "setup_watchos_target.sh not found in current directory"
            exit 1
        fi
        ;;
    "open-sims")
        open_simulators
        ;;
    "show-sims")
        show_simulators
        ;;
    "full")
        echo_status "Running full build and test sequence..."
        show_simulators
        echo ""
        
        # Build both platforms
        ios_success=false
        watchos_success=false
        
        if build_ios; then
            ios_success=true
        fi
        
        if [ -n "$WATCH_SCHEME" ]; then
            if build_watchos; then
                watchos_success=true
            fi
        else
            echo_warning "No watchOS scheme found. Run './setup_watchos_target.sh' to add watchOS support"
        fi
        
        if [ "$ios_success" = true ]; then
            open_simulators
            setup_watch_pairing
            launch_ios
            
            # Try to launch watchOS app if available
            if [ -n "$WATCH_SCHEME" ] && [ "$watchos_success" = true ]; then
                echo_status "Attempting to launch watchOS app..."
                if launch_watchos; then
                    echo_success "🎉 Complete setup! Both iOS and watchOS apps built and launched."
                    echo_status "Both apps are now running on their respective simulators."
                else
                    echo_success "🎉 Setup complete! Both apps built, iOS launched."
                    echo_status "watchOS app built but launch failed - you can install it manually from Xcode."
                fi
            else
                echo_success "🎉 iOS setup complete! iOS simulator ready."
                echo ""
                echo_status "No watchOS target detected. Running watchOS setup guide..."
                if [ -f "./setup_watchos_target.sh" ]; then
                    echo_status "Executing watchOS setup script..."
                    ./setup_watchos_target.sh
                else
                    echo_warning "setup_watchos_target.sh not found. You can add watchOS support manually through Xcode."
                    echo_status "To add watchOS target: File → New → Target → watchOS → Watch App"
                fi
            fi
        else
            echo_error "iOS build failed. Please fix errors and try again."
            exit 1
        fi
        ;;
    "help"|*)
        show_usage
        ;;
esac
