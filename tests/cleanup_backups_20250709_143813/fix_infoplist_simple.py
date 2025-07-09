#!/usr/bin/env python3
import os
import re
import sys
import shutil
import subprocess

# Colors for output
HEADER = '\033[95m'
BLUE = '\033[94m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
ENDC = '\033[0m'
BOLD = '\033[1m'

# File paths
PROJECT_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                         "ShuttlX.xcodeproj", "project.pbxproj")
BACKUP_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "project.pbxproj.infoplist_fix_backup")

def create_backup():
    """Create a backup of the project file"""
    print(f"{BLUE}📦 Creating backup at {BACKUP_PATH}{ENDC}")
    shutil.copy2(PROJECT_FILE, BACKUP_PATH)
    print(f"{GREEN}✅ Backup created{ENDC}")

def fix_info_plist_issue():
    """Fix the Info.plist issue by removing from Resources phase"""
    print(f"{HEADER}🔍 Looking for Info.plist in Resources phase...{ENDC}")
    
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
    
    # Find all PBXResourcesBuildPhase sections
    resource_phases = re.finditer(r'(\w+) /\* Resources \*/ = {\n\s+isa = PBXResourcesBuildPhase;(?:.|\n)*?files = \(\n((?:.|\n)*?)\);', content)
    
    found_info_plist = False
    new_content = content
    
    for match in resource_phases:
        phase_id = match.group(1)
        files_section = match.group(2)
        
        # Check for Info.plist in this resource phase
        info_plist_match = re.search(r'(\w+) /\* Info\.plist in Resources \*/', files_section)
        if info_plist_match:
            found_info_plist = True
            info_plist_id = info_plist_match.group(1)
            print(f"{BLUE}ℹ️ Found Info.plist in Resources phase: {phase_id}, ID: {info_plist_id}{ENDC}")
            
            # Remove the Info.plist entry from the resources phase
            # Handle case where it's the only entry
            if files_section.strip() == info_plist_id + " /* Info.plist in Resources */,":
                pattern = rf'{info_plist_id} /\* Info\.plist in Resources \*/,'
                replacement = ""
            # Handle case where it's the last entry
            elif re.search(rf',\s*{info_plist_id} /\* Info\.plist in Resources \*/\s*$', files_section):
                pattern = rf',\s*{info_plist_id} /\* Info\.plist in Resources \*/'
                replacement = ""
            # Handle case where it's followed by other entries
            else:
                pattern = rf'{info_plist_id} /\* Info\.plist in Resources \*/,\s*'
                replacement = ""
            
            # Update only the specific resource phase
            updated_files_section = re.sub(pattern, replacement, files_section)
            new_content = new_content.replace(match.group(2), updated_files_section)
            
            print(f"{GREEN}✅ Removed Info.plist from Resources phase{ENDC}")
    
    if not found_info_plist:
        print(f"{YELLOW}⚠️ No Info.plist found in any Resources phase{ENDC}")
        return True
    
    # Write the updated content back to the project file
    with open(PROJECT_FILE, 'w') as f:
        f.write(new_content)
    
    return True

def check_manual_steps_needed():
    """Check if manual steps are needed"""
    print(f"{HEADER}🔍 Checking if manual steps are needed...{ENDC}")
    
    # Check if the Swift files exist in the iOS project
    view_files = [
        "ShuttlX/Views/SyncDebugView.swift",
        "ShuttlX/Views/SettingsView.swift",
        "ShuttlX/Views/OnboardingView.swift"
    ]
    
    missing_files = []
    for file_path in view_files:
        file_name = os.path.basename(file_path)
        full_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), file_path)
        
        if not os.path.exists(full_path):
            print(f"{RED}❌ File does not exist on disk: {file_path}{ENDC}")
            missing_files.append(file_path)
        else:
            print(f"{GREEN}✅ File exists on disk: {file_path}{ENDC}")
    
    if missing_files:
        print(f"{YELLOW}⚠️ Some files are missing and need to be created:{ENDC}")
        for file_path in missing_files:
            print(f"  - {file_path}")
    
    print(f"\n{YELLOW}📋 Manual steps in Xcode are still needed:{ENDC}")
    print(f"1. Open ShuttlX.xcodeproj in Xcode")
    print(f"2. Right-click on the Views folder in the iOS target")
    print(f"3. Select 'Add Files to ShuttlX...'")
    print(f"4. Navigate to and select the Swift files")
    print(f"5. Make sure the following files are added:")
    for file_path in view_files:
        print(f"  - {file_path}")

def main():
    print(f"{HEADER}🛠️  ShuttlX Info.plist Fix Tool{ENDC}")
    print(f"{HEADER}{'=' * 40}{ENDC}")
    
    # Create a backup of the project file
    create_backup()
    
    # Fix the Info.plist issue
    if not fix_info_plist_issue():
        print(f"{RED}❌ Failed to fix Info.plist issue{ENDC}")
        return
    
    # Check if manual steps are needed
    check_manual_steps_needed()
    
    print(f"\n{GREEN}{BOLD}✅ Info.plist fix complete!{ENDC}")
    print(f"\n{YELLOW}📋 Next steps:{ENDC}")
    print(f"{YELLOW}1. Run the build script:{ENDC}")
    print(f"   ./tests/build_and_test_both_platforms.sh --ios-only --build")
    print(f"{YELLOW}2. If build still fails, try manual steps in Xcode{ENDC}")

if __name__ == "__main__":
    main()
