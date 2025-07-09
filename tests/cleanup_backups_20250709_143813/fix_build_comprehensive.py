#!/usr/bin/env python3
import os
import re
import sys
import uuid
import shutil
import subprocess
from pathlib import Path

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
BACKUP_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "project.pbxproj.comprehensive_backup")

# Missing Swift files
MISSING_FILES = [
    "ShuttlX/Views/SyncDebugView.swift",
    "ShuttlX/Views/SettingsView.swift",
    "ShuttlX/Views/OnboardingView.swift"
]

def create_backup():
    """Create a backup of the project file"""
    print(f"{BLUE}📦 Creating backup at {BACKUP_PATH}{ENDC}")
    shutil.copy2(PROJECT_FILE, BACKUP_PATH)
    print(f"{GREEN}✅ Backup created{ENDC}")

def fix_duplicate_info_plist():
    """Fix the duplicate Info.plist issue in the watchOS target"""
    print(f"{HEADER}🔍 Fixing duplicate Info.plist in watchOS target...{ENDC}")
    
    # Read the project file
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
    
    # Look for the watchOS target
    watch_target_match = re.search(r'(\w+) /\* ShuttlXWatch Watch App Watch App \*/ = {[\s\S]*?isa = PBXNativeTarget', content)
    if not watch_target_match:
        print(f"{RED}❌ Could not find watchOS target{ENDC}")
        return False
    
    watch_target_id = watch_target_match.group(1)
    print(f"{BLUE}ℹ️ watchOS target ID: {watch_target_id}{ENDC}")
    
    # Find resource build phases for the watchOS target
    resource_phase_match = re.search(rf'{watch_target_id} /\* ShuttlXWatch Watch App Watch App \*/ = {{[\s\S]*?buildPhases = \(([\s\S]*?)\);', content)
    if not resource_phase_match:
        print(f"{RED}❌ Could not find build phases for watchOS target{ENDC}")
        return False
    
    build_phases = resource_phase_match.group(1)
    resource_phase = re.search(r'(\w+) /\* Resources \*/', build_phases)
    if not resource_phase:
        print(f"{YELLOW}⚠️ No Resources build phase found for watchOS target{ENDC}")
        return True
    
    resource_phase_id = resource_phase.group(1)
    print(f"{BLUE}ℹ️ Resources build phase ID: {resource_phase_id}{ENDC}")
    
    # Find the Info.plist reference in the Resources build phase
    resource_section_match = re.search(rf'{resource_phase_id} /\* Resources \*/ = {{[\s\S]*?files = \(([\s\S]*?)\);', content)
    if not resource_section_match:
        print(f"{YELLOW}⚠️ Could not find files in Resources build phase{ENDC}")
        return True
    
    resource_files = resource_section_match.group(1)
    
    # Look for Info.plist in the resources
    info_plist_match = re.search(r'(\w+) /\* Info\.plist in Resources \*/', resource_files)
    if not info_plist_match:
        print(f"{GREEN}✅ No Info.plist found in Resources build phase - no fix needed{ENDC}")
        return True
    
    info_plist_build_file_id = info_plist_match.group(1)
    print(f"{BLUE}ℹ️ Found Info.plist in Resources with ID: {info_plist_build_file_id}{ENDC}")
    
    # Remove the Info.plist from the Resources build phase
    if ',' in info_plist_match.group(0):
        # If there's a comma after the Info.plist entry
        pattern = rf'{info_plist_build_file_id} /\* Info\.plist in Resources \*/,\s*'
        new_content = re.sub(pattern, '', content)
    else:
        # If there's a comma before the Info.plist entry
        pattern = rf',\s*{info_plist_build_file_id} /\* Info\.plist in Resources \*/'
        new_content = re.sub(pattern, '', content)
        
        # If the above didn't work (no comma before), try removing just the entry
        if new_content == content:
            pattern = rf'{info_plist_build_file_id} /\* Info\.plist in Resources \*/\s*'
            new_content = re.sub(pattern, '', content)
    
    # Write the updated content back to the project file
    with open(PROJECT_FILE, 'w') as f:
        f.write(new_content)
    
    print(f"{GREEN}✅ Removed Info.plist from Resources build phase of watchOS target{ENDC}")
    return True

def add_missing_swift_files():
    """Add the missing Swift files to the iOS target"""
    print(f"{HEADER}🔍 Adding missing Swift files to iOS target...{ENDC}")
    
    # Read the project file
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
    
    # Get iOS target ID
    ios_target_match = re.search(r'(\w+) /\* ShuttlX \*/ = {[\s\S]*?isa = PBXNativeTarget', content)
    if not ios_target_match:
        print(f"{RED}❌ Could not find iOS target{ENDC}")
        return False
    
    ios_target_id = ios_target_match.group(1)
    print(f"{BLUE}ℹ️ iOS target ID: {ios_target_id}{ENDC}")
    
    # Get sources build phase ID for iOS target
    sources_phase_match = re.search(rf'{ios_target_id} /\* ShuttlX \*/ = {{[\s\S]*?buildPhases = \(([\s\S]*?)\);', content)
    if not sources_phase_match:
        print(f"{RED}❌ Could not find build phases for iOS target{ENDC}")
        return False
    
    build_phases = sources_phase_match.group(1)
    sources_phase = re.search(r'(\w+) /\* Sources \*/', build_phases)
    if not sources_phase:
        print(f"{RED}❌ Could not find Sources build phase for iOS target{ENDC}")
        return False
    
    sources_phase_id = sources_phase.group(1)
    print(f"{BLUE}ℹ️ Sources build phase ID: {sources_phase_id}{ENDC}")
    
    # Get Views group ID
    views_group_match = re.search(r'(\w+) /\* Views \*/ = {[\s\S]*?isa = PBXGroup', content)
    if not views_group_match:
        print(f"{RED}❌ Could not find Views group{ENDC}")
        return False
    
    views_group_id = views_group_match.group(1)
    print(f"{BLUE}ℹ️ Views group ID: {views_group_id}{ENDC}")
    
    # Process each missing file
    file_refs_to_add = []
    build_files_to_add = []
    group_children_to_add = []
    sources_files_to_add = []
    
    for file_path in MISSING_FILES:
        file_name = os.path.basename(file_path)
        print(f"{BLUE}ℹ️ Processing {file_name}...{ENDC}")
        
        # Check if file reference already exists
        file_ref_match = re.search(rf'(\w+) /\* {file_name} \*/ = {{.*?path = {file_name}', content)
        if file_ref_match:
            file_ref_id = file_ref_match.group(1)
            print(f"{YELLOW}⚠️ File reference already exists for {file_name}: {file_ref_id}{ENDC}")
        else:
            file_ref_id = str(uuid.uuid4()).upper().replace('-', '')[:24]
            file_refs_to_add.append((file_name, file_ref_id))
        
        # Check if build file already exists
        build_file_match = re.search(rf'(\w+) /\* {file_name} in Sources \*/ = {{.*?fileRef = {file_ref_id}', content)
        if build_file_match:
            build_file_id = build_file_match.group(1)
            print(f"{YELLOW}⚠️ Build file already exists for {file_name}: {build_file_id}{ENDC}")
        else:
            build_file_id = str(uuid.uuid4()).upper().replace('-', '')[:24]
            build_files_to_add.append((file_name, file_ref_id, build_file_id))
        
        # Check if file is already in Views group
        views_children_match = re.search(rf'{views_group_id} /\* Views \*/ = {{[\s\S]*?children = \(([\s\S]*?)\);', content)
        if views_children_match:
            views_children = views_children_match.group(1)
            if file_ref_id not in views_children:
                group_children_to_add.append((file_name, file_ref_id))
        
        # Check if build file is already in Sources build phase
        sources_files_match = re.search(rf'{sources_phase_id} /\* Sources \*/ = {{[\s\S]*?files = \(([\s\S]*?)\);', content)
        if sources_files_match:
            sources_files = sources_files_match.group(1)
            if build_file_id not in sources_files:
                sources_files_to_add.append((file_name, build_file_id))
    
    # Add file references
    for file_name, file_ref_id in file_refs_to_add:
        file_ref_section_match = re.search(r'\/\* Begin PBXFileReference section \*\/\n([\s\S]*?)\/\* End PBXFileReference section \*\/', content)
        if file_ref_section_match:
            file_ref_section = file_ref_section_match.group(1)
            file_ref_entry = f'\t\t{file_ref_id} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = "{file_name}"; path = "{file_path}"; sourceTree = SOURCE_ROOT; }};\n'
            new_file_ref_section = file_ref_section + file_ref_entry
            content = content.replace(file_ref_section, new_file_ref_section)
            print(f"{GREEN}✅ Added file reference for {file_name}{ENDC}")
    
    # Add build files
    for file_name, file_ref_id, build_file_id in build_files_to_add:
        build_file_section_match = re.search(r'\/\* Begin PBXBuildFile section \*\/\n([\s\S]*?)\/\* End PBXBuildFile section \*\/', content)
        if build_file_section_match:
            build_file_section = build_file_section_match.group(1)
            build_file_entry = f'\t\t{build_file_id} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {file_name} */; }};\n'
            new_build_file_section = build_file_section + build_file_entry
            content = content.replace(build_file_section, new_build_file_section)
            print(f"{GREEN}✅ Added build file for {file_name}{ENDC}")
    
    # Add files to Views group
    for file_name, file_ref_id in group_children_to_add:
        views_group_pattern = rf'({views_group_id} /\* Views \*/ = {{[\s\S]*?children = \(\n)([\s\S]*?)(\);)'
        views_group_match = re.search(views_group_pattern, content)
        if views_group_match:
            prefix = views_group_match.group(1)
            children = views_group_match.group(2)
            suffix = views_group_match.group(3)
            
            # If there are existing children, add a comma at the end
            if children.strip():
                if children.strip().endswith(','):
                    new_children = children + f'\t\t\t\t{file_ref_id} /* {file_name} */,\n'
                else:
                    new_children = children.rstrip() + f',\n\t\t\t\t{file_ref_id} /* {file_name} */,\n'
            else:
                new_children = f'\t\t\t\t{file_ref_id} /* {file_name} */,\n'
            
            content = content.replace(prefix + children + suffix, prefix + new_children + suffix)
            print(f"{GREEN}✅ Added {file_name} to Views group{ENDC}")
    
    # Add files to Sources build phase
    for file_name, build_file_id in sources_files_to_add:
        sources_phase_pattern = rf'({sources_phase_id} /\* Sources \*/ = {{[\s\S]*?files = \(\n)([\s\S]*?)(\);)'
        sources_phase_match = re.search(sources_phase_pattern, content)
        if sources_phase_match:
            prefix = sources_phase_match.group(1)
            files = sources_phase_match.group(2)
            suffix = sources_phase_match.group(3)
            
            # If there are existing files, add a comma at the end
            if files.strip():
                if files.strip().endswith(','):
                    new_files = files + f'\t\t\t\t{build_file_id} /* {file_name} in Sources */,\n'
                else:
                    new_files = files.rstrip() + f',\n\t\t\t\t{build_file_id} /* {file_name} in Sources */,\n'
            else:
                new_files = f'\t\t\t\t{build_file_id} /* {file_name} in Sources */,\n'
            
            content = content.replace(prefix + files + suffix, prefix + new_files + suffix)
            print(f"{GREEN}✅ Added {file_name} to Sources build phase{ENDC}")
    
    # Write the updated content back to the project file
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)
    
    return True

def main():
    print(f"{HEADER}🛠️  ShuttlX Comprehensive Build Fix Tool{ENDC}")
    print(f"{HEADER}{'=' * 40}{ENDC}")
    
    # Create a backup of the project file
    create_backup()
    
    # Fix the duplicate Info.plist issue
    if not fix_duplicate_info_plist():
        print(f"\n{RED}{BOLD}❌ Failed to fix duplicate Info.plist issue{ENDC}")
        return
    
    # Add missing Swift files to the iOS target
    if not add_missing_swift_files():
        print(f"\n{RED}{BOLD}❌ Failed to add missing Swift files{ENDC}")
        return
    
    print(f"\n{GREEN}{BOLD}✅ Successfully applied fixes to the project!{ENDC}")
    print(f"\n{YELLOW}📋 Next steps:{ENDC}")
    print(f"{YELLOW}1. Run the build script:{ENDC}")
    print(f"   ./tests/build_and_test_both_platforms.sh --ios-only --build")
    print(f"{YELLOW}2. If build still fails, restore from backup:{ENDC}")
    print(f"   cp {BACKUP_PATH} {PROJECT_FILE}")
    print(f"{YELLOW}3. Then try manual steps in Xcode{ENDC}")

if __name__ == "__main__":
    main()
