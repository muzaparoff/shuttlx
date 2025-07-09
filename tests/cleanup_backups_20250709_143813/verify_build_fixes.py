#!/usr/bin/env python3
import os
import re
import sys
import subprocess

print("🔍 ShuttlX Build Verification Tool")
print("=================================")

# Define paths
project_root = '/Users/sergey/Documents/github/shuttlx'
project_path = os.path.join(project_root, 'ShuttlX.xcodeproj/project.pbxproj')
info_plist_path = os.path.join(project_root, 'ShuttlXWatch Watch App Watch App/Info.plist')
ios_missing_files = [
    'ShuttlX/Views/SyncDebugView.swift',
    'ShuttlX/Views/SettingsView.swift',
    'ShuttlX/Views/OnboardingView.swift'
]

# Step 1: Check if Info.plist exists
print("\n📋 Checking Info.plist file...")
if os.path.exists(info_plist_path):
    print(f"✅ Info.plist exists at {info_plist_path}")
else:
    print(f"❌ Info.plist MISSING at {info_plist_path}")
    print("   This file is required for the build. Please restore it.")

# Step 2: Check missing Swift files
print("\n📋 Checking iOS Swift files...")
all_files_exist = True
for file in ios_missing_files:
    full_path = os.path.join(project_root, file)
    if os.path.exists(full_path):
        print(f"✅ {file} exists")
    else:
        print(f"❌ {file} MISSING")
        all_files_exist = False

if not all_files_exist:
    print("❌ Some iOS Swift files are missing. Please restore them.")
else:
    print("✅ All required Swift files exist on disk")

# Step 3: Run a test build to see if the issue is fixed
print("\n📋 Running test build (iOS only)...")
build_cmd = "./tests/build_and_test_both_platforms.sh --ios-only --build"
process = subprocess.Popen(build_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

# We don't need full output, just want to check the result
stdout, stderr = process.communicate()
exit_code = process.returncode

if exit_code == 0:
    print("✅ BUILD SUCCESSFUL! The Info.plist issue has been resolved.")
    print("   All fixes have been applied successfully.")
else:
    print("❌ Build still failing. Error code:", exit_code)
    
    # Look for specific error patterns
    stdout_str = stdout.decode('utf-8')
    if "Multiple commands produce" in stdout_str and "Info.plist" in stdout_str:
        print("\n❌ Info.plist duplicate issue still present.")
        print("   The following manual fix in Xcode is required:")
        print("   1. Open ShuttlX.xcodeproj in Xcode")
        print("   2. Select ShuttlXWatch Watch App Watch App target")
        print("   3. Go to Build Phases tab")
        print("   4. Expand Copy Bundle Resources")
        print("   5. Find Info.plist and remove it")
        print("   6. Clean and rebuild")
    elif "missing from iOS project target" in stdout_str:
        print("\n❌ Swift files still missing from iOS target.")
        print("   Please add them manually in Xcode:")
        print("   1. Open ShuttlX.xcodeproj in Xcode")
        print("   2. Right-click on iOS target's Views folder")
        print("   3. Select 'Add Files to ShuttlX...'")
        print("   4. Add missing Swift files")
    else:
        print("\n❓ Different build error detected. See build log for details.")

print("\n📋 Verification complete!")

# Exit with the same code as the build
sys.exit(0 if exit_code == 0 else 1)
