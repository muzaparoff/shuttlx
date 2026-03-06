#!/bin/bash

# ShuttlX - Build and Test Script for iOS and watchOS
# This script builds and tests both platforms as per the phased rewrite plan
#
# Usage: ./build_and_test_both_platforms.sh [flags]
#
# Basic Flags:
#   --clean          Clean before build
#   --build          Build the project (default if no flags provided)
#   --install        Install on simulators (default if no flags provided)
#   --test           Run tests
#   --launch         Launch apps after installation
#   --ios-only       Only build iOS targets
#   --watchos-only   Only build watchOS targets
#
# Debug Flags:
#   --debug-freeze   Enable freeze debugging instrumentation (automatically enables build and install)

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Define the project root as the parent of SCRIPT_DIR
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Note: We handle errors manually rather than using 'set -e' for better control

# Parse command line arguments
CLEAN=false
BUILD=false
INSTALL=false
TEST=false
LAUNCH=false
IOS_ONLY=false
WATCHOS_ONLY=false
DEBUG_MODE=false  # New flag for debugging freezing issues

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
        --debug-freeze)
            DEBUG_MODE=true
            BUILD=true
            INSTALL=true
            echo "🐞 DEBUG MODE: Enabled for freeze troubleshooting (automatically enabling build and install)"
            shift
            ;;
        *)
            echo "Unknown option $1"
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

# Build timeout in seconds
BUILD_TIMEOUT=300

# Portable timeout: use gtimeout (Homebrew coreutils), timeout (Linux), or no timeout
if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout"
elif command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout"
else
    TIMEOUT_CMD=""
fi

# Helper: Build a target with proper timeout and error handling
build_target() {
    local target="$1"
    local sdk="$2"
    local destination="$3"
    local platform_name="$4"
    
    echo "\n🔨 Building $platform_name target: $target"
    echo "SDK: $sdk"
    echo "Destination: $destination"
    
    local build_action="build"
    local clean_first=false
    if [ "$CLEAN" = true ]; then
        clean_first=true
    fi
    
    echo "Command line invocation:"
    if [ "$clean_first" = true ]; then
        echo "    (cd \"$PROJECT_ROOT\" && /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ShuttlX.xcodeproj -target \"$target\" -sdk \"$sdk\" -destination \"$destination\" CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO clean)"
        echo "    (cd \"$PROJECT_ROOT\" && /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ShuttlX.xcodeproj -target \"$target\" -sdk \"$sdk\" -destination \"$destination\" CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build)"
    else
        echo "    (cd \"$PROJECT_ROOT\" && /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project ShuttlX.xcodeproj -target \"$target\" -sdk \"$sdk\" -destination \"$destination\" CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build)"
    fi
    echo ""
    
    # Clean first if requested
    if [ "$clean_first" = true ]; then
        echo "🧹 Cleaning $platform_name target..."
        (cd "$PROJECT_ROOT" && ${TIMEOUT_CMD:+$TIMEOUT_CMD $BUILD_TIMEOUT} xcodebuild -project ShuttlX.xcodeproj -target "$target" -sdk "$sdk" -destination "$destination" \
            CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
            clean 2>&1 | tee "/tmp/clean_${platform_name}.log")
        local clean_exit_code=$?
        if [ $clean_exit_code -ne 0 ]; then
            echo "⚠️  Clean failed (exit code: $clean_exit_code), but continuing with build..."
        fi
    fi

    # Run the build and capture output and exit code properly
    echo "🚀 Starting $platform_name build..."
    
    # Use a more reliable approach to capture both output and exit code
    set +e  # Temporarily disable exit on error
    
    # Create a temporary script to capture the exact exit code from xcodebuild
    local temp_script="/tmp/build_${platform_name}_script.sh"
    
    # Debug mode configuration
    local debug_flags=""
    if [ "$DEBUG_MODE" = true ]; then
        echo "🐞 Adding debug flags for freeze troubleshooting..."
        debug_flags="OTHER_SWIFT_FLAGS='-D DEBUG_FREEZE'"
    fi
    
    cat > "$temp_script" << EOF
#!/bin/bash
${TIMEOUT_CMD:+$TIMEOUT_CMD $BUILD_TIMEOUT} xcodebuild -project ShuttlX.xcodeproj -target "$target" -sdk "$sdk" -destination "$destination" \\
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \\
    $debug_flags \\
    $build_action
echo "XCODEBUILD_EXIT_CODE: \$?" >&2
EOF
    chmod +x "$temp_script"
    
    # Run the script and capture both stdout and stderr
    "$temp_script" > "/tmp/build_${platform_name}.log" 2>&1
    
    # Extract the actual exit code from xcodebuild (not from the shell pipeline)
    local exit_code=$(grep "XCODEBUILD_EXIT_CODE:" "/tmp/build_${platform_name}.log" | tail -1 | cut -d':' -f2 | tr -d ' ')
    if [ -z "$exit_code" ]; then
        exit_code=1  # If we can't find the exit code, assume failure
    fi
    
    # Clean up the temporary script
    rm -f "$temp_script"
    
    # Note: NOT re-enabling set -e — script handles errors manually (see line 25)

    # Display the build output (excluding the exit code line)
    grep -v "XCODEBUILD_EXIT_CODE:" "/tmp/build_${platform_name}.log" || true
    
    # Check the exit code first - this is the definitive indicator
    echo "\n🔍 Build Exit Code Analysis:"
    echo "   Platform: $platform_name"
    echo "   Exit Code: $exit_code"
    if [ $exit_code -eq 0 ]; then
        echo "✅ $platform_name build successful!"
        return 0
    elif [ $exit_code -eq 124 ]; then
        echo "❌ $platform_name build TIMED OUT after $BUILD_TIMEOUT seconds"
        echo "� Build log saved to: /tmp/build_${platform_name}.log"
        echo "📄 Last 20 lines of error log:"
        tail -20 "/tmp/build_${platform_name}.log"
        return 1
    else
        # Build failed - check if it's a compilation error or just code signing
        if grep -q -E "(BUILD FAILED|error:|Error:|The following build commands failed)" "/tmp/build_${platform_name}.log"; then
            echo "❌ $platform_name BUILD FAILED with compilation errors! (exit code: $exit_code)"
            echo "📄 Build log saved to: /tmp/build_${platform_name}.log"
            echo "📄 Critical errors from build log:"
            echo "----------------------------------------"
            grep -A5 -B2 -E "(BUILD FAILED|error:|Error:|The following build commands failed)" "/tmp/build_${platform_name}.log" | tail -30
            echo "----------------------------------------"
            return 1
        elif grep -q "CodeSign.*failed" "/tmp/build_${platform_name}.log"; then
            echo "⚠️  $platform_name build completed with expected code signing error (simulator)"
            echo "✅ $platform_name compilation successful!"
            return 0
        else
            echo "❌ $platform_name build failed with unknown error (exit code: $exit_code)"
            echo "📄 Build log saved to: /tmp/build_${platform_name}.log"
            echo "📄 Last 20 lines of error log:"
            tail -20 "/tmp/build_${platform_name}.log"
            return 1
        fi
    fi
}

# Helper: Get simulator UDID by name and runtime
get_sim_udid() {
    local device_name="$1"
    local runtime="$2"
    xcrun simctl list devices | grep "$device_name" | grep "$runtime" | head -1 | sed 's/.*(\([^)]*\)).*/\1/'
}

# Helper: Install app on simulator
install_app() {
    local device_name="$1"
    local app_path="$2"
    local platform_name="$3"
    
    echo "\n📲 Installing $platform_name app on $device_name..."
    echo "App path: $app_path"
    
    if [ ! -d "$app_path" ]; then
        echo "❌ App not found at path: $app_path"
        return 1
    fi
    
    if xcrun simctl install "$device_name" "$app_path"; then
        echo "✅ $platform_name app installed successfully!"
        return 0
    else
        echo "❌ Failed to install $platform_name app"
        return 1
    fi
}

# Helper: Launch app on simulator
launch_app() {
    local device_name="$1"
    local bundle_id="$2"
    local platform_name="$3"
    
    echo "\n🚀 Launching $platform_name app on $device_name..."
    echo "Bundle ID: $bundle_id"
    
    if xcrun simctl launch "$device_name" "$bundle_id"; then
        echo "✅ $platform_name app launched successfully!"
        return 0
    else
        echo "❌ Failed to launch $platform_name app"
        return 1
    fi
}

# Auto-add missing Swift files to iOS project target
auto_fix_missing_files() {
    echo "🔍 Checking for missing Swift files in iOS project target..."
    
    PROJECT_FILE="ShuttlX.xcodeproj/project.pbxproj"
    # Removed backup file creation - direct modifications only
    
    # Find all Swift files in the ShuttlX/ directory (excluding test files)
    local missing_files=()
    while IFS= read -r file; do
        filename=$(basename "$file")
        # Skip backup files and test files
        if [[ "$filename" == *"backup"* ]] || [[ "$file" == *"Test"* ]]; then
            continue
        fi
        
        # Check if file is already referenced in project.pbxproj
        if ! grep -q "$filename" "$PROJECT_FILE"; then
            missing_files+=("$file")
        fi
    done < <(find ShuttlX -name "*.swift" -type f)
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        echo "✅ All Swift files are already included in iOS project target"
        return 0
    fi
    
    echo "📋 Found ${#missing_files[@]} Swift files missing from iOS project target:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    
    echo "🔧 Automatically adding missing files to iOS project target..."
    
    # No backup created - direct modifications only
    echo "� Modifying project file directly (no backup)"
    
    # Generate unique IDs for new files
    local base_id_num=5923520  # Start after likely existing IDs
    local file_ref_ids=()
    local build_file_ids=()
    
    # Generate IDs for each missing file
    local file_index=0
    for file in "${missing_files[@]}"; do
        local file_ref_id="A${base_id_num}"
        local build_file_id="A$((base_id_num + 1000))"
        
        file_ref_ids+=("$file_ref_id")
        build_file_ids+=("$build_file_id")
        
        ((base_id_num++))
        ((file_index++))
    done
    
    # Create temporary file for modifications
    local temp_file=$(mktemp)
    cp "$PROJECT_FILE" "$temp_file"
    
    echo "📝 Adding PBXBuildFile entries..."
    
    # Build the PBXBuildFile entries
    local build_file_entries=""
    local file_index=0
    for file in "${missing_files[@]}"; do
        local filename=$(basename "$file")
        build_file_entries+="\t\t${build_file_ids[$file_index]} /* $filename in Sources */ = {isa = PBXBuildFile; fileRef = ${file_ref_ids[$file_index]} /* $filename */; };\n"
        ((file_index++))
    done
    
    # Insert build file entries after existing PBXBuildFile entries
    if grep -q "A5923502.*ContentView.swift in Sources" "$temp_file"; then
        sed -i '' "/A5923502.*ContentView.swift in Sources.*fileRef.*A5923508.*ContentView.swift/a\\
$build_file_entries" "$temp_file"
    else
        echo "⚠️  Could not find expected PBXBuildFile insertion point"
        rm "$temp_file"
        return 1
    fi
    
    echo "📁 Adding PBXFileReference entries..."
    
    # Build the PBXFileReference entries
    local file_ref_entries=""
    local file_index=0
    for file in "${missing_files[@]}"; do
        local filename=$(basename "$file")
        local relative_path=$(echo "$file" | sed 's|^ShuttlX/||')  # Remove ShuttlX/ prefix
        file_ref_entries+="\t\t${file_ref_ids[$file_index]} /* $filename */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"$relative_path\"; sourceTree = \"<group>\"; };\n"
        ((file_index++))
    done
    
    # Insert file reference entries after existing PBXFileReference entries
    if grep -q "A5923508.*ContentView.swift.*PBXFileReference" "$temp_file"; then
        sed -i '' "/A5923508.*ContentView.swift.*PBXFileReference.*sourcecode.swift.*path = ContentView.swift/a\\
$file_ref_entries" "$temp_file"
    else
        echo "⚠️  Could not find expected PBXFileReference insertion point"
        rm "$temp_file"
        return 1
    fi
    
    echo "⚡ Adding files to iOS Sources build phase..."
    
    # Build the Sources build phase entries
    local sources_entries=""
    local file_index=0
    for file in "${missing_files[@]}"; do
        local filename=$(basename "$file")
        sources_entries+="\t\t\t${build_file_ids[$file_index]} /* $filename in Sources */,\n"
        ((file_index++))
    done
    
    # Insert into iOS Sources build phase (A59234DA)
    if grep -q "A5923502.*ContentView.swift in Sources.*," "$temp_file"; then
        sed -i '' "/A5923502.*ContentView.swift in Sources.*,/a\\
$sources_entries" "$temp_file"
    else
        echo "⚠️  Could not find expected Sources build phase insertion point"
        rm "$temp_file"
        return 1
    fi
    
    echo "📂 Adding files to group structure..."
    
    # Build the group entries
    local group_entries=""
    local file_index=0
    for file in "${missing_files[@]}"; do
        local filename=$(basename "$file")
        group_entries+="\t\t\t${file_ref_ids[$file_index]} /* $filename */,\n"
        ((file_index++))
    done
    
    # Insert into group structure (after ContentView.swift in group)
    if grep -q "A5923508.*ContentView.swift.*," "$temp_file"; then
        sed -i '' "/A5923508.*ContentView.swift.*,/a\\
$group_entries" "$temp_file"
    else
        echo "⚠️  Could not find expected group insertion point"
        rm "$temp_file"
        return 1
    fi
    
    # Validate the modified project file by checking basic syntax
    if grep -q "// !\\$\\*UTF8\\*\\$!" "$temp_file" && grep -q "archiveVersion = 1;" "$temp_file"; then
        # Replace original file with modified version
        mv "$temp_file" "$PROJECT_FILE"
        echo "✅ Successfully added ${#missing_files[@]} Swift files to iOS project target!"
        
        echo "📋 Files added:"
        for file in "${missing_files[@]}"; do
            echo "  ✅ $file"
        done
        
        return 0
    else
        echo "❌ Project file validation failed"
        rm "$temp_file"
        return 1
    fi
}

# Helper: Boot simulators and pair watch to phone
boot_and_pair_simulators() {
    local phone_name="iPhone 17 Pro"
    local watch_name="Apple Watch Series 11 (46mm)"

    echo "📱 Booting $phone_name simulator..."
    xcrun simctl boot "$phone_name" 2>/dev/null || true  # already booted is OK

    echo "⌚ Booting $watch_name simulator..."
    xcrun simctl boot "$watch_name" 2>/dev/null || true

    # Open Simulator.app to show the devices
    open -a Simulator

    # Check if already paired
    local phone_udid=$(xcrun simctl list devices available | grep "$phone_name" | head -1 | grep -oE '[0-9A-F-]{36}')
    local watch_udid=$(xcrun simctl list devices available | grep "$watch_name" | head -1 | grep -oE '[0-9A-F-]{36}')

    if [ -n "$phone_udid" ] && [ -n "$watch_udid" ]; then
        local already_paired=$(xcrun simctl list pairs | grep -A2 "$phone_udid" | grep "$watch_udid")
        if [ -z "$already_paired" ]; then
            echo "🔗 Pairing $watch_name ↔ $phone_name..."
            xcrun simctl pair "$watch_udid" "$phone_udid" 2>/dev/null || echo "⚠️  Pairing skipped (may already exist)"
        else
            echo "✅ Already paired"
        fi
    fi

    echo "✅ Simulators ready"
}

function run_preflight_checks() {
    echo "🔍 Running preflight checks..."
    
    # Check for Info.plist resources in Copy Bundle Resources
    if [ -f "$SCRIPT_DIR/remove_infoplist_from_resources.py" ]; then
        echo "  - Checking for Info.plist duplication in resources..."
        python3 "$SCRIPT_DIR/remove_infoplist_from_resources.py"
    else
        echo "  - ⚠️ Script remove_infoplist_from_resources.py not found, skipping check"
    fi
    
    # Check for conflicting WatchKit keys in Info.plist
    if [ -f "$SCRIPT_DIR/fix_watchkit_infoplist_keys.py" ]; then
        echo "  - Checking for conflicting WatchKit keys in Info.plist..."
        python3 "$SCRIPT_DIR/fix_watchkit_infoplist_keys.py"
    else
        echo "  - ⚠️ Script fix_watchkit_infoplist_keys.py not found, skipping check"
    fi
    
    echo "✅ Preflight checks completed"
    echo ""
}

# Main build logic
if [ "$BUILD" = true ]; then
    # Boot simulators and pair watch↔phone
    boot_and_pair_simulators

    # Run preflight checks before building
    run_preflight_checks
    
    build_failed=false
    
    if [ "$IOS_ONLY" != true ]; then
        echo "\n⌚ Building watchOS target first..."
        
        if build_target "ShuttlX Watch App" "watchsimulator" "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2" "watchOS"; then
            
            # Detect and preserve watchOS app
            WATCHOS_APP_PATH="build/Release-watchsimulator/ShuttlX Watch App.app"
            if [ -d "$WATCHOS_APP_PATH" ]; then
                echo "🔍 watchOS app path detected: $WATCHOS_APP_PATH"
                
                # Copy to temp location to preserve it
                cp -r "$WATCHOS_APP_PATH" "/tmp/ShuttlXWatch_Watch_App.app"
                echo "💾 watchOS app preserved to: /tmp/ShuttlXWatch_Watch_App.app"
            fi
        else
            echo "❌ watchOS build failed"
            build_failed=true
        fi
    fi
    
    if [ "$WATCHOS_ONLY" != true ]; then
        echo "\n📱 Building iOS target (independent)..."
        
        # Automatically fix missing Swift files before building
        if ! auto_fix_missing_files; then
            echo "⚠️  Advanced project file manipulation failed, trying Python alternative..."
            if command -v python3 >/dev/null 2>&1; then
                python3 "${SCRIPT_DIR}/auto_fix_files.py"
            else
                echo "💡 Alternative: Run 'python3 ${SCRIPT_DIR}/auto_fix_files.py' to get detailed manual instructions"
            fi
        fi
        
        if build_target "ShuttlX" "iphonesimulator" "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2" "iOS"; then
            
            # Detect iOS app
            IOS_APP_PATH="build/Release-iphonesimulator/ShuttlX.app"
            if [ -d "$IOS_APP_PATH" ]; then
                echo "🔍 iOS app path detected: $IOS_APP_PATH"
            fi
        else
            echo "❌ iOS build failed"
            build_failed=true
        fi
    fi
    
    # Exit immediately if any build failed
    if [ "$build_failed" = true ]; then
        echo "\n💥 BUILD SCRIPT STOPPED: One or more builds failed!"
        echo "🚫 Installation and testing skipped due to build failures."
        echo "📋 Please fix the compilation errors above and try again."
        exit 1
    fi
fi

# Installation logic
if [ "$INSTALL" = true ]; then
    if [ "$IOS_ONLY" != true ]; then
        # Install watchOS app
        WATCHOS_APP_PATH="build/Release-watchsimulator/ShuttlX Watch App.app"
        if [ ! -d "$WATCHOS_APP_PATH" ] && [ -d "/tmp/ShuttlXWatch_Watch_App.app" ]; then
            WATCHOS_APP_PATH="/tmp/ShuttlXWatch_Watch_App.app"
        fi
        
        if [ -d "$WATCHOS_APP_PATH" ]; then
            install_app "Apple Watch Series 11 (46mm)" "$WATCHOS_APP_PATH" "watchOS"
        else
            echo "⚠️  watchOS app not found for installation"
        fi
    fi
    
    if [ "$WATCHOS_ONLY" != true ]; then
        # Install iOS app
        IOS_APP_PATH="build/Release-iphonesimulator/ShuttlX.app"
        if [ -d "$IOS_APP_PATH" ]; then
            install_app "iPhone 17 Pro" "$IOS_APP_PATH" "iOS"
        else
            echo "⚠️  iOS app not found for installation"
        fi
    fi
fi

# Launch logic
if [ "$LAUNCH" = true ]; then
    if [ "$IOS_ONLY" != true ]; then
        # Launch watchOS app
        launch_app "Apple Watch Series 11 (46mm)" "com.shuttlx.ShuttlX.watchkitapp" "watchOS"
    fi
    
    if [ "$WATCHOS_ONLY" != true ]; then
        # Launch iOS app
        launch_app "iPhone 17 Pro" "com.shuttlx.ShuttlX" "iOS"
    fi
fi

echo "\n🎉 Script completed successfully!"
echo "📋 Summary:"
echo "  - Build: $BUILD"
echo "  - Install: $INSTALL" 
echo "  - Launch: $LAUNCH"
echo ""
