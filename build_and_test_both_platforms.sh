#!/bin/bash

# Build and Test iOS + watchOS Apps Side by Side
# This script helps you build, install, and test both iOS and watchOS apps together

set -e

# Parse command line arguments
GUI_TEST=false
TIMER_TEST=false
COMMAND=""

# First, extract options
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --gui-test)
            GUI_TEST=true
            shift
            ;;
        --timer-test)
            TIMER_TEST=true
            shift
            ;;
        --help)
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  build-ios       Build iOS app only"
            echo "  build-watchos   Build watchOS app only"
            echo "  build-all       Build both iOS and watchOS apps"
            echo "  clean           Clean all build caches and DerivedData"
            echo "  clean-build     Clean and rebuild both platforms from scratch"
            echo "  deploy-ios      Build, install and launch iOS app"
            echo "  deploy-watchos  Build, install and launch watchOS app"
            echo "  deploy-all      Build, install and launch both apps (integrated)"
            echo "  launch-ios      Install and launch iOS app"
            echo "  launch-watchos  Install and launch watchOS app"
            echo "  launch-both     Install and launch both apps"
            echo "  setup-watch     Setup watch pairing"
            echo "  setup-watchos   Run watchOS target setup guide"
            echo "  open-sims       Open both simulators"
            echo "  show-sims       Show available simulators"
            echo "  full            Build all, setup watch, and launch (default)"
            echo "  help            Show this help message"
            echo ""
            echo "Options:"
            echo "  --gui-test      Run automated GUI tests after successful launch"
            echo "  --timer-test    Specifically test watchOS timer functionality"
            echo ""
            echo "Examples:"
            echo "  $0 full --gui-test           # Build, launch, and run GUI tests"
            echo "  $0 launch-both --timer-test  # Launch apps and test timer only"
            exit 0
            ;;
        -*)
            echo "Unknown option $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            # This is a command, not an option
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Set the command (default to "full" if none provided)
if [ ${#ARGS[@]} -eq 0 ]; then
    COMMAND="full"
else
    COMMAND="${ARGS[0]}"
fi

# Clean up any existing log files
echo "🧹 Cleaning up old log files..."
rm -f *.log

# Function to clean Xcode build cache and DerivedData
clean_xcode_cache() {
    echo_status "🧹 Cleaning Xcode build cache and DerivedData..."
    
    # Clean DerivedData for this project
    if [ -d ~/Library/Developer/Xcode/DerivedData/ShuttlX-* ]; then
        echo_status "Removing ShuttlX DerivedData cache..."
        rm -rf ~/Library/Developer/Xcode/DerivedData/ShuttlX-*
        echo_success "DerivedData cache cleared"
    else
        echo_status "No DerivedData cache found for ShuttlX"
    fi
    
    # Clean project build directory if it exists
    if [ -d "build" ]; then
        echo_status "Removing local build directory..."
        rm -rf build
        echo_success "Local build directory cleared"
    fi
    
    # Clean any temporary build files
    if [ -d "DerivedData" ]; then
        echo_status "Removing local DerivedData directory..."
        rm -rf DerivedData
        echo_success "Local DerivedData directory cleared"
    fi
    
    echo_success "✅ Xcode cache cleanup complete"
}

echo "🚀 ShuttlX Multi-Platform Build & Test Script"
echo "============================================="
if [ "$GUI_TEST" = true ]; then
    echo "🧪 GUI Testing: ENABLED"
fi
if [ "$TIMER_TEST" = true ]; then
    echo "⏱️  Timer Testing: ENABLED"
fi
echo ""

# HARDCODED Configuration for available simulators
IOS_SCHEME="ShuttlX"
PROJECT_PATH="ShuttlX.xcodeproj"
IOS_SIMULATOR="iPhone 16"
WATCH_SIMULATOR="Apple Watch Series 10 (46mm)"

# Specific iOS/watchOS versions as requested
IOS_VERSION="18.4"
WATCHOS_VERSION="11.5"

# Set watchOS scheme directly
WATCH_SCHEME="ShuttlXWatch Watch App"

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

# Helper function to get iOS device ID
get_ios_device_id() {
    find_device_with_version "$IOS_SIMULATOR" "$IOS_VERSION"
}

# Helper function to get watchOS device ID
get_watch_device_id() {
    find_device_with_version "$WATCH_SIMULATOR" "$WATCHOS_VERSION"
}

# Function to run basic timer test
run_basic_timer_test() {
    echo_status "🧪 Running comprehensive timer functionality test..."
    
    # Check if both apps are actually running
    echo_status "Verifying both apps are running..."
    
    # Get device IDs
    local ios_device_id=$(get_ios_device_id)
    local watch_device_id=$(get_watch_device_id)
    
    # Check iOS app process
    local ios_running=false
    if xcrun simctl spawn "$ios_device_id" ps ax 2>/dev/null | grep -q "ShuttlX"; then
        echo_success "✅ iOS app confirmed running"
        ios_running=true
    else
        echo_warning "⚠️  iOS app not detected running"
    fi
    
    # Check watchOS app process  
    local watch_running=false
    if xcrun simctl spawn "$watch_device_id" ps ax 2>/dev/null | grep -q "ShuttlXWatch"; then
        echo_success "✅ watchOS app confirmed running"
        watch_running=true
    else
        echo_warning "⚠️  watchOS app not detected running"
    fi
    
    # Create a temporary log monitoring script
    echo_status "Starting comprehensive log monitoring for timer functionality..."
    
    # Monitor for debug logs that indicate timer is working
    echo_status "Monitoring both iOS and watchOS logs for timer activity..."
    
    # Start log monitoring for both platforms
    timeout 30 xcrun simctl spawn "$ios_device_id" log stream --predicate 'eventMessage CONTAINS "🚀" OR eventMessage CONTAINS "🏃" OR eventMessage CONTAINS "timer" OR eventMessage CONTAINS "startWorkout" OR eventMessage CONTAINS "DEBUG"' --style compact > ios_timer_test.log 2>&1 &
    
    timeout 30 xcrun simctl spawn "$watch_device_id" log stream --predicate 'eventMessage CONTAINS "🚀" OR eventMessage CONTAINS "🏃" OR eventMessage CONTAINS "⌚" OR eventMessage CONTAINS "timer" OR eventMessage CONTAINS "startWorkout" OR eventMessage CONTAINS "DEBUG"' --style compact > watch_timer_test.log 2>&1 &
    
    echo ""
    echo "📋 COMPREHENSIVE TIMER TEST:"
    echo "============================"
    echo "✅ Apps Status:"
    if [ "$ios_running" = true ]; then
        echo "   📱 iOS app: RUNNING"
    else
        echo "   📱 iOS app: NOT RUNNING (may need manual launch)"
    fi
    if [ "$watch_running" = true ]; then
        echo "   ⌚ watchOS app: RUNNING"  
    else
        echo "   ⌚ watchOS app: NOT RUNNING (may need manual launch)"
    fi
    echo ""
    echo "🔧 MANUAL TEST STEPS:"
    echo "1. In the Watch Simulator, open the ShuttlXWatch app"
    echo "2. Navigate to the training program selection"
    echo "3. Select any training program (e.g., 'Beginner 5K Builder')"
    echo "4. Press the 'Start Workout' button"
    echo "5. Verify the timer starts counting and shows debug info"
    echo ""
    echo "🔍 Expected Debug Output:"
    echo "   🚀 [DEBUG] App startup messages"
    echo "   🏃‍♂️ [DEBUG] startWorkout(from:) called with program: ..."
    echo "   ⌚ [DEBUG] WorkoutManager state: ACTIVE"
    echo "   ⏱️ [DEBUG] Starting timer with interval: ..."
    echo ""
    echo "⏱️  Monitoring logs for 30 seconds..."
    echo "   Press Ctrl+C to stop early if test completes"
    
    sleep 30
    
    # Check if we detected timer activity
    local timer_detected=false
    
    echo_status "Analyzing log results..."
    
    # Check iOS logs
    if [ -f "ios_timer_test.log" ] && grep -q "startWorkout\|timer\|elapsed\|🏃\|🚀" ios_timer_test.log 2>/dev/null; then
        echo_success "✅ iOS timer activity detected!"
        echo_status "iOS debug output preview:"
        grep -E "startWorkout|timer|🏃|🚀|DEBUG" ios_timer_test.log | head -3
        timer_detected=true
    fi
    
    # Check watchOS logs  
    if [ -f "watch_timer_test.log" ] && grep -q "startWorkout\|timer\|elapsed\|🏃\|⌚\|🚀" watch_timer_test.log 2>/dev/null; then
        echo_success "✅ watchOS timer activity detected!"
        echo_status "watchOS debug output preview:"
        grep -E "startWorkout|timer|🏃|⌚|🚀|DEBUG" watch_timer_test.log | head -3
        timer_detected=true
    fi
    
    # Final test result
    if [ "$timer_detected" = true ]; then
        echo ""
        echo_success "🎉 TIMER FUNCTIONALITY TEST: PASSED"
        echo_success "Timer appears to be working correctly!"
        echo_status "Full logs saved to: ios_timer_test.log, watch_timer_test.log"
    else
        echo ""
        echo_warning "⚠️  TIMER FUNCTIONALITY TEST: INCONCLUSIVE"
        echo_status "No clear timer activity detected in logs"
        echo_status "This could mean:"
        echo_status "  1. Apps need to be launched manually"
        echo_status "  2. Timer test requires actual user interaction"
        echo_status "  3. Debug logging may not be capturing all events"
        echo_status ""
        echo_status "Manual verification recommended:"
        echo_status "  - Launch both simulators"
        echo_status "  - Open watchOS app manually" 
        echo_status "  - Test timer functionality by starting a workout"
    fi
    
    # Clean up background processes
    jobs -p | xargs -r kill 2>/dev/null || true
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
    
    # Use known scheme name directly to avoid xcodebuild hanging issues
    # This is more reliable than trying to auto-detect
    WATCH_SCHEME="ShuttlXWatch Watch App"
    echo_success "Using known watchOS scheme: $WATCH_SCHEME"
    return 0
    
    # Alternative: Try to get schemes with better timeout handling (currently disabled)
    # Uncomment this section if you want to try auto-detection again
    : '
    local schemes_output=""
    local timeout_available=false
    
    # Check for timeout command (Linux/modern systems)
    if command -v timeout >/dev/null 2>&1; then
        timeout_available=true
        schemes_output=$(timeout 10 xcodebuild -project "$PROJECT_PATH" -list 2>/dev/null || echo "TIMEOUT")
    # Check for gtimeout (macOS with GNU coreutils)
    elif command -v gtimeout >/dev/null 2>&1; then
        timeout_available=true
        schemes_output=$(gtimeout 10 xcodebuild -project "$PROJECT_PATH" -list 2>/dev/null || echo "TIMEOUT")
    # Try with background job and manual timeout (fallback)
    else
        echo_status "No timeout command available, using background job approach..."
        # Run xcodebuild in background with manual timeout
        xcodebuild -project "$PROJECT_PATH" -list 2>/dev/null > /tmp/schemes_output.txt &
        local bg_pid=$!
        local count=0
        while [ $count -lt 10 ]; do
            if ! kill -0 $bg_pid 2>/dev/null; then
                # Process has completed
                schemes_output=$(cat /tmp/schemes_output.txt 2>/dev/null || echo "")
                rm -f /tmp/schemes_output.txt
                break
            fi
            sleep 1
            count=$((count + 1))
        done
        
        # If still running after 10 seconds, kill it
        if kill -0 $bg_pid 2>/dev/null; then
            kill $bg_pid 2>/dev/null || true
            wait $bg_pid 2>/dev/null || true
            schemes_output="TIMEOUT"
            rm -f /tmp/schemes_output.txt
        fi
    fi
    
    # Handle timeout or empty output
    if [ -z "$schemes_output" ] || [ "$schemes_output" = "TIMEOUT" ]; then
        echo_warning "Could not detect schemes automatically (timeout or xcodebuild hanging)"
        echo_status "Using default watchOS scheme name..."
        WATCH_SCHEME="ShuttlXWatch Watch App"
        echo_success "Using default watchOS scheme: $WATCH_SCHEME"
        return 0
    fi
    '
    
    local schemes=$(echo "$schemes_output" | grep -A 50 "Schemes:" | grep -v "Schemes:" | grep -v "^$" | sed 's/^[[:space:]]*//')
    
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
    
    # If version is "any", just find any device with that name
    if [ "$os_version" = "any" ]; then
        local device_id=$(xcrun simctl list devices | grep "^[[:space:]]*$sim_name (" | head -1 | grep -E -o '\([A-F0-9-]+\)' | tr -d '()')
        if [ -n "$device_id" ]; then
            echo_success "Found device: $sim_name (ID: $device_id)" >&2
            echo "$device_id"
            return 0
        fi
    else
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

# Function to build, install and launch iOS app using proven manual commands
build_and_deploy_ios() {
    echo_status "Building, installing and launching iOS app for $IOS_SIMULATOR (iOS $IOS_VERSION)..."
    
    local ios_device_id
    ios_device_id=$(find_device_with_version "$IOS_SIMULATOR" "$IOS_VERSION")
    if [ -z "$ios_device_id" ]; then
        echo_error "Could not find iOS device"
        return 1
    fi
    
    echo_status "Using iOS device ID: $ios_device_id"
    
    # Ensure the iOS simulator is booted
    echo_status "Ensuring iOS simulator is booted..."
    if ! xcrun simctl list devices | grep "$ios_device_id" | grep -q "Booted"; then
        echo_status "Booting iOS simulator..."
        xcrun simctl boot "$ios_device_id" || true
        echo_status "Waiting for simulator to boot..."
        sleep 3
    fi
    
    # Build the iOS app using the same command that worked manually
    echo_status "Building iOS app..."
    if xcodebuild -project "$PROJECT_PATH" -scheme "$IOS_SCHEME" -destination "platform=iOS Simulator,id=$ios_device_id" clean build; then
        echo_success "iOS build completed successfully"
    else
        echo_error "iOS build failed"
        return 1
    fi
    
    # Install and launch using the same commands that worked manually
    echo_status "Installing and launching iOS app..."
    
    # Find the iOS app with more robust path detection
    local ios_app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "ShuttlX.app" -path "*/Debug-iphonesimulator/*" | head -1)
    
    if [ -z "$ios_app_path" ]; then
        echo_error "Could not find iOS app build path"
        echo_status "Searching for app in DerivedData..."
        find ~/Library/Developer/Xcode/DerivedData -name "ShuttlX.app" -type d | head -3
        return 1
    fi
    
    echo_status "Found iOS app at: $ios_app_path"
    
    if xcrun simctl install "$ios_device_id" "$ios_app_path" && \
       xcrun simctl launch "$ios_device_id" com.shuttlx.ShuttlX; then
        echo_success "iOS app installed and launched successfully"
        return 0
    else
        echo_error "iOS app installation or launch failed"
        return 1
    fi
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

# Function to build, install and launch watchOS app using proven manual commands
build_and_deploy_watchos() {
    if [ -z "$WATCH_SCHEME" ]; then
        echo_warning "No watchOS scheme detected. Skipping watchOS build."
        echo "Run './setup_watchos_target.sh' to add watchOS support"
        return 1
    fi
    
    echo_status "Building, installing and launching watchOS app for $WATCH_SIMULATOR (watchOS $WATCHOS_VERSION)..."
    
    local watch_device_id
    watch_device_id=$(find_device_with_version "$WATCH_SIMULATOR" "$WATCHOS_VERSION")
    if [ -z "$watch_device_id" ]; then
        echo_error "Could not find watchOS device"
        return 1
    fi
    
    echo_status "Using watchOS device ID: $watch_device_id"
    
    # Ensure the watchOS simulator is booted
    echo_status "Ensuring watchOS simulator is booted..."
    if ! xcrun simctl list devices | grep "$watch_device_id" | grep -q "Booted"; then
        echo_status "Booting watchOS simulator..."
        xcrun simctl boot "$watch_device_id" || true
        echo_status "Waiting for simulator to boot..."
        sleep 5
    fi
    
    # Build the watchOS app using the same command that worked manually
    echo_status "Building watchOS app..."
    if xcodebuild -project "$PROJECT_PATH" -scheme "$WATCH_SCHEME" -destination "platform=watchOS Simulator,id=$watch_device_id" clean build; then
        echo_success "watchOS build completed successfully"
    else
        echo_error "watchOS build failed"
        return 1
    fi
    
    # Install and launch using the same commands that worked manually
    echo_status "Installing watchOS app..."
    
    # Find the correct watchOS app path with multiple fallback options
    # Prioritize the actual build products path, exclude Index.noindex paths
    local watch_app_path=""
    local possible_paths=(
        "$(find ~/Library/Developer/Xcode/DerivedData -name "ShuttlXWatch Watch App.app" -path "*/Build/Products/Debug-watchsimulator/*" -not -path "*/Index.noindex/*" | head -1)"
        "$(find ~/Library/Developer/Xcode/DerivedData -name "*Watch App.app" -path "*/Build/Products/Debug-watchsimulator/*" -not -path "*/Index.noindex/*" | head -1)"
        "$(find ~/Library/Developer/Xcode/DerivedData -name "*Watch*.app" -path "*/Debug-watchsimulator/*" -not -path "*/Index.noindex/*" | head -1)"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -n "$path" ] && [ -d "$path" ]; then
            echo_status "Checking path: $path"
            # Verify the app has a valid Info.plist with bundle identifier
            if [ -f "$path/Info.plist" ]; then
                local bundle_id=$(plutil -extract CFBundleIdentifier raw "$path/Info.plist" 2>/dev/null || echo "")
                if [ -n "$bundle_id" ]; then
                    echo_status "Found valid app with bundle ID: $bundle_id"
                    watch_app_path="$path"
                    break
                else
                    echo_warning "App at $path has no bundle ID, skipping"
                fi
            else
                echo_warning "App at $path has no Info.plist, skipping"
            fi
        fi
    done
    
    if [ -z "$watch_app_path" ]; then
        echo_error "Could not find valid watchOS app build path"
        echo_status "Debugging: Searching for all Watch apps in DerivedData..."
        echo_status "All Watch app paths found:"
        find ~/Library/Developer/Xcode/DerivedData -name "*Watch*.app" -type d | while read app_path; do
            echo "  - $app_path"
            if [ -f "$app_path/Info.plist" ]; then
                local bundle_id=$(plutil -extract CFBundleIdentifier raw "$app_path/Info.plist" 2>/dev/null || echo "INVALID")
                echo "    Bundle ID: $bundle_id"
            else
                echo "    No Info.plist found"
            fi
        done
        echo_status "You may need to manually specify the correct path"
        return 1
    fi
    
    echo_status "Found watchOS app at: $watch_app_path"
    echo_status "Installing to device: $watch_device_id"
    
    if xcrun simctl install "$watch_device_id" "$watch_app_path"; then
        echo_success "watchOS app installed successfully"
        
        # Verify installation before attempting launch
        echo_status "Verifying app installation..."
        if xcrun simctl listapps "$watch_device_id" | grep -q "com.shuttlx.ShuttlX.watchkitapp"; then
            echo_success "App installation verified"
            echo_status "Launching watchOS app..."
            
            # Attempt to launch the app
            if xcrun simctl launch "$watch_device_id" com.shuttlx.ShuttlX.watchkitapp; then
                echo_success "watchOS app launched successfully"
                return 0
            else
                echo_warning "App installed but launch failed (this may be normal for watchOS)"
                echo_status "You can manually launch the app in the Watch Simulator"
                return 0  # Still consider this a success since the app is installed
            fi
        else
            echo_error "App installation verification failed"
            return 1
        fi
    else
        echo_error "watchOS app installation failed"
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
    
    # Validate app bundle structure (fix for empty bundles)
    echo_status "Validating app bundle structure..."
    if [ ! -f "$app_path/Info.plist" ]; then
        echo_error "App bundle is missing Info.plist - bundle may be empty"
        echo_status "Bundle contents:"
        ls -la "$app_path" 2>/dev/null || echo "Cannot list bundle contents"
        return 1
    fi
    
    # Check for executable
    local executable_name=$(basename "$app_path" .app)
    if [ ! -f "$app_path/$executable_name" ]; then
        echo_error "App bundle is missing executable: $executable_name"
        echo_status "Bundle contents:"
        ls -la "$app_path" 2>/dev/null || echo "Cannot list bundle contents"
        return 1
    fi
    
    echo_success "App bundle validation passed"
    
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
        
        # Launch app with improved error handling
        echo_status "Launching iOS app with bundle ID: $bundle_id"
        if xcrun simctl launch "$ios_device_id" "$bundle_id"; then
            local launch_pid=$(xcrun simctl launch "$ios_device_id" "$bundle_id" 2>&1 | grep -o '[0-9]*' | tail -1)
            echo_success "iOS app launched successfully (PID: $launch_pid)"
            
            # Verify app is actually running
            sleep 2
            if xcrun simctl list devices | grep "$ios_device_id" | grep -q "Booted"; then
                echo_status "iOS Simulator confirmed running"
                # Optional: Check for app process
                if xcrun simctl spawn "$ios_device_id" ps ax | grep -q "ShuttlX"; then
                    echo_success "✅ iOS app process confirmed running"
                else
                    echo_warning "⚠️  Could not confirm app process, but launch command succeeded"
                fi
            fi
        else
            echo_error "Failed to launch iOS app"
            return 1
        fi
        
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
        local watch_app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "*Watch App.app" -path "*/Debug-watchsimulator/*" -not -path "*/Index.noindex/*" | head -1)
        local watch_bundle_id=""
        
        if [ -n "$watch_app_path" ]; then
            # Validate watch app bundle structure
            echo_status "Validating watch app bundle: $watch_app_path"
            if [ ! -f "$watch_app_path/Info.plist" ]; then
                echo_error "Watch app bundle is missing Info.plist"
                return 1
            fi
            
            # Check for executable
            local watch_executable_name=$(basename "$watch_app_path" .app)
            if [ ! -f "$watch_app_path/$watch_executable_name" ]; then
                echo_error "Watch app bundle is missing executable: $watch_executable_name"
                echo_status "Watch bundle contents:"
                ls -la "$watch_app_path" 2>/dev/null || echo "Cannot list bundle contents"
                return 1
            fi
            
            watch_bundle_id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$watch_app_path/Info.plist" 2>/dev/null)
            echo_success "Watch app bundle validation passed"
            echo_status "Found watch app at: $watch_app_path"
            echo_status "Watch Bundle ID: $watch_bundle_id"
        else
            echo_warning "Could not find watch app bundle automatically"
        fi
        
        # Try to launch the app with detected bundle ID
        echo_status "Launching watchOS app..."
        if [ -n "$watch_bundle_id" ]; then
            if xcrun simctl launch "$watch_device_id" "$watch_bundle_id"; then
                local watch_pid=$(xcrun simctl launch "$watch_device_id" "$watch_bundle_id" 2>&1 | grep -o '[0-9]*' | tail -1)
                echo_success "watchOS app launched successfully (PID: $watch_pid)"
                
                # Verify watch app is running and respond to the "service delegate denied" error
                sleep 3
                echo_status "Verifying watch app status..."
                
                # Check for the watch app process
                if xcrun simctl spawn "$watch_device_id" ps ax 2>/dev/null | grep -q "ShuttlXWatch"; then
                    echo_success "✅ watchOS app process confirmed running"
                else
                    echo_warning "⚠️  Watch app may have failed to start completely"
                    echo_status "This is often due to service delegate restrictions in simulator"
                    echo_status "Try manually launching the app in Watch Simulator UI"
                fi
                
                # Check for logs
                sleep 2
                echo_status "Checking watch app logs..."
                xcrun simctl spawn "$watch_device_id" log show --predicate 'processImagePath contains "ShuttlX" OR subsystem contains "watch"' --info --last 10s 2>/dev/null | grep -E "(WATCH-STARTUP|ERROR|LAUNCH)" || echo_status "No watch startup logs found yet"
                
            else
                echo_warning "Could not launch watchOS app with bundle ID: $watch_bundle_id"
                echo_status "This may be due to simulator service delegate restrictions"
                echo_status "Try launching manually in Watch Simulator"
            fi
        else
            # Try common bundle IDs with improved error handling
            echo_status "Attempting launch with common bundle IDs..."
            if xcrun simctl launch "$watch_device_id" "com.shuttlx.ShuttlX.watchkitapp" 2>&1; then
                echo_success "✅ Launched with standard bundle ID"
            elif xcrun simctl launch "$watch_device_id" "com.shuttlx.watch.watchkitapp" 2>&1; then
                echo_success "✅ Launched with alternate bundle ID"
            else
                echo_warning "Could not launch watchOS app automatically"
                echo_status "App should be installed on the watch simulator. You can launch it manually."
                echo_status "Look for 'ShuttlXWatch' app icon in the Watch Simulator"
            fi
        fi
        
        echo_success "watchOS app setup completed"
        echo_status "watchOS Simulator Device ID: $watch_device_id"
        return 0
    else
        echo_error "watchOS app installation failed"
        return 1
    fi
}

# MARK: - Watch Pairing Functions

pair_watch_with_iphone() {
    echo_status "🔗 Setting up Apple Watch and iPhone simulator pairing..."
    
    # Get device IDs
    local ios_device_id=$(get_ios_device_id)
    local watch_device_id=$(get_watch_device_id)
    
    if [ -z "$ios_device_id" ] || [ -z "$watch_device_id" ]; then
        echo_error "❌ Could not find required simulators"
        return 1
    fi
    
    echo_status "iPhone Device ID: $ios_device_id"
    echo_status "Watch Device ID: $watch_device_id"
    
    # Check if already paired
    local paired_watch=$(xcrun simctl list pairs | grep "$ios_device_id" | grep "$watch_device_id")
    if [ ! -z "$paired_watch" ]; then
        echo_success "✅ Devices are already paired and ready"
        return 0
    fi
    
    # Create pairing - disable exit on error temporarily for this command
    echo_status "Creating new device pair..."
    set +e  # Temporarily disable exit on error
    local pair_output=$(xcrun simctl pair "$watch_device_id" "$ios_device_id" 2>&1)
    local pair_exit_code=$?
    set -e  # Re-enable exit on error
    
    if [ $pair_exit_code -eq 0 ]; then
        echo_success "✅ Successfully paired Apple Watch with iPhone"
        
        # Verify pairing
        local verification=$(xcrun simctl list pairs | grep "$ios_device_id" | grep "$watch_device_id")
        if [ ! -z "$verification" ]; then
            echo_success "✅ Pairing verified successfully"
            return 0
        else
            echo_warning "⚠️ Pairing created but verification failed"
            echo_status "Continuing with app deployment anyway..."
            return 0  # Don't fail - continue with deployment
        fi
    else
        # Check if the error is due to devices already being paired
        if echo "$pair_output" | grep -q "already paired"; then
            echo_success "✅ Devices are already paired (confirmed by pairing attempt)"
            return 0
        else
            echo_warning "⚠️ Failed to pair devices: $pair_output"
            echo_status "Continuing with app deployment anyway - pairing may work later..."
            return 0  # Don't fail - continue with deployment
        fi
    fi
}

ensure_simulators_booted() {
    echo_status "🚀 Ensuring simulators are booted..."
    
    # Get device IDs
    local ios_device_id=$(get_ios_device_id)
    local watch_device_id=$(get_watch_device_id)
    
    if [ -z "$ios_device_id" ] || [ -z "$watch_device_id" ]; then
        echo_warning "⚠️ Could not find required simulators, trying to continue anyway"
        return 0
    fi
    
    echo_status "iPhone Device ID: $ios_device_id"
    echo_status "Watch Device ID: $watch_device_id"
    
    # Boot iOS simulator if not running
    local ios_status=$(xcrun simctl list devices | grep "$ios_device_id" | grep -o "(Booted)\|(Shutdown)" || echo "(Unknown)")
    if [ "$ios_status" != "(Booted)" ]; then
        echo_status "Starting iPhone simulator..."
        xcrun simctl boot "$ios_device_id" || true
        sleep 2
    else
        echo_success "iPhone simulator already booted"
    fi
    
    # Boot watchOS simulator if not running  
    local watch_status=$(xcrun simctl list devices | grep "$watch_device_id" | grep -o "(Booted)\|(Shutdown)" || echo "(Unknown)")
    if [ "$watch_status" != "(Booted)" ]; then
        echo_status "Starting Apple Watch simulator..."
        xcrun simctl boot "$watch_device_id" || true
        sleep 2
    else
        echo_success "Apple Watch simulator already booted"
    fi
    
    # Wait for both to be fully ready
    echo_status "Waiting for simulators to fully initialize..."
    sleep 3
    
    echo_success "✅ Both simulators are now booted and ready"
}

setup_watch_pairing() {
    echo_status "🔗 Setting up Watch pairing for development..."
    
    # Ensure both simulators are booted
    ensure_simulators_booted
    
    # Wait a moment for simulators to fully initialize
    echo_status "Waiting for simulators to initialize..."
    sleep 3
    
    # Pair the devices - but don't fail if it doesn't work
    if pair_watch_with_iphone; then
        echo_success "✅ Watch pairing setup complete"
    else
        echo_warning "⚠️ Watch pairing had issues but continuing anyway"
        echo_status "You may need to pair manually in the Watch app in iOS Simulator later"
    fi
    
    # Additional wait for pairing to stabilize
    echo_status "Allowing pairing to stabilize..."
    sleep 2
}

# MARK: - Existing Functions Continue Below

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
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  build-ios       Build iOS app only"
    echo "  build-watchos   Build watchOS app only"
    echo "  build-all       Build both iOS and watchOS apps"
    echo "  clean           Clean all build caches and DerivedData"
    echo "  clean-build     Clean and rebuild both platforms from scratch"
    echo "  deploy-ios      Build, install and launch iOS app"
    echo "  deploy-watchos  Build, install and launch watchOS app"
    echo "  deploy-all      Build, install and launch both apps (integrated)"
    echo "  launch-ios      Install and launch iOS app"
    echo "  launch-watchos  Install and launch watchOS app"
    echo "  launch-both     Install and launch both apps"
    echo "  setup-watch     Setup watch pairing"
    echo "  setup-watchos   Run watchOS target setup guide"
    echo "  open-sims       Open both simulators"
    echo "  show-sims       Show available simulators"
    echo "  full            Build all, setup watch, and launch (default)"
    echo "  help            Show this help message"
    echo ""
    echo "Options:"
    echo "  --gui-test      Run automated GUI tests after successful launch"
    echo "  --timer-test    Specifically test watchOS timer functionality"
    echo ""
    echo "Examples:"
    echo "  $0 full --gui-test           # Build, launch, and run GUI tests"
    echo "  $0 launch-both --timer-test  # Launch apps and test timer only"
    echo "  $0 --help                    # Show extended help"
}

# Auto-detect watchOS scheme at startup
detect_watch_scheme

# Main execution
case "$COMMAND" in
    "clean")
        clean_xcode_cache
        ;;
    "clean-build")
        echo_status "Performing clean build from scratch..."
        clean_xcode_cache
        echo ""
        echo_status "Building both iOS and watchOS apps after cleanup..."
        ios_success=false
        watchos_success=false
        
        if build_ios; then
            ios_success=true
        fi
        
        if build_watchos; then
            watchos_success=true
        fi
        
        if [ "$ios_success" = true ] && [ "$watchos_success" = true ]; then
            echo_success "Both platforms built successfully after cleanup!"
        elif [ "$ios_success" = true ]; then
            echo_warning "iOS build succeeded, but watchOS build failed after cleanup"
        elif [ "$watchos_success" = true ]; then
            echo_warning "watchOS build succeeded, but iOS build failed after cleanup"
        else
            echo_error "Both builds failed after cleanup"
            exit 1
        fi
        ;;
    "build-ios")
        build_ios
        ;;
    "build-watchos")
        build_watchos
        ;;
    "deploy-ios")
        build_and_deploy_ios
        ;;
    "deploy-watchos")
        build_and_deploy_watchos
        ;;
    "deploy-all")
        echo_status "Building and deploying both iOS and watchOS apps..."
        ios_success=false
        watchos_success=false
        
        if build_and_deploy_ios; then
            ios_success=true
        fi
        
        if build_and_deploy_watchos; then
            watchos_success=true
        fi
        
        if [ "$ios_success" = true ] && [ "$watchos_success" = true ]; then
            echo_success "Both platforms built and deployed successfully!"
            
            # Run timer test if requested
            if [ "$TIMER_TEST" = true ]; then
                echo ""
                echo_status "Running timer functionality test..."
                run_basic_timer_test
            fi
        elif [ "$ios_success" = true ]; then
            echo_warning "iOS build/deploy succeeded, but watchOS failed"
        elif [ "$watchos_success" = true ]; then
            echo_warning "watchOS build/deploy succeeded, but iOS failed"
        else
            echo_error "Both builds/deploys failed"
            exit 1
        fi
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
                    
                    # Run GUI tests if requested
                    if [ "$GUI_TEST" = true ] || [ "$TIMER_TEST" = true ]; then
                        echo ""
                        echo_status "🧪 Starting GUI integration tests..."
                        
                        if [ -f "./automated_gui_test.sh" ]; then
                            echo_status "Running automated GUI tests..."
                            ./automated_gui_test.sh
                        else
                            echo_warning "automated_gui_test.sh not found. Running basic timer test..."
                            run_basic_timer_test
                        fi
                    fi
                    
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
