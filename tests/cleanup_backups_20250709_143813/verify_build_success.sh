#!/bin/bash

# This is a verification script that runs after manual Xcode fixes
# to confirm the build is now working

echo -e "\e[1;36m📋 ShuttlX Build Verification Script\e[0m"
echo -e "\e[1;36m==================================\e[0m"

# Create a function to print with color
print_green() {
  echo -e "\e[1;32m✅ $1\e[0m"
}

print_red() {
  echo -e "\e[1;31m❌ $1\e[0m"
}

print_yellow() {
  echo -e "\e[1;33m⚠️ $1\e[0m"
}

print_blue() {
  echo -e "\e[1;34m🔍 $1\e[0m"
}

# Check if project file is valid
print_blue "Checking project file validity..."
if [ -f "ShuttlX.xcodeproj/project.pbxproj" ]; then
  print_green "Project file exists"
else
  print_red "Project file missing"
  exit 1
fi

# Check for missing Swift files
print_blue "Checking Swift files on disk..."
files_to_check=(
  "ShuttlX/Views/SyncDebugView.swift"
  "ShuttlX/Views/SettingsView.swift"
  "ShuttlX/Views/OnboardingView.swift"
)

all_files_exist=true
for file in "${files_to_check[@]}"; do
  if [ -f "$file" ]; then
    print_green "$file exists on disk"
  else
    print_red "$file missing on disk"
    all_files_exist=false
  fi
done

if [ "$all_files_exist" = false ]; then
  print_red "Some required files are missing on disk"
  exit 1
fi

# Run a test build
print_blue "Running test build..."
echo -e "\e[1;33m==================================\e[0m"
echo -e "\e[1;33mBuilding iOS target...\e[0m"
./tests/build_and_test_both_platforms.sh --ios-only --build

# Check the result
if [ $? -eq 0 ]; then
  print_green "Build succeeded! Manual fixes have resolved the issues."
  echo ""
  print_green "✨ PHASE 18 COMPLETED SUCCESSFULLY! ✨"
  echo ""
  print_blue "Next steps:"
  echo "1. Update AI_AGENT_GUIDE.md to mark Phase 18 as complete"
  echo "2. Proceed with Phase 19 objectives"
else
  print_red "Build failed. Manual fixes may not be complete."
  echo ""
  print_yellow "Please ensure you have:"
  echo "1. Removed Info.plist from Copy Bundle Resources in watchOS target"
  echo "2. Added all missing Swift files to iOS target"
  echo "3. Cleaned the build folder"
  echo ""
  print_blue "Try again after making these changes in Xcode."
fi
