#!/usr/bin/env python3
import os
import re
import sys
import uuid
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
BACKUP_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "project.pbxproj.add_files_backup")

# Missing Swift files
MISSING_FILES = [
    "ShuttlX/Views/SyncDebugView.swift",
    "ShuttlX/Views/SettingsView.swift",
    "ShuttlX/Views/OnboardingView.swift"
]

def create_backup():
    """Create a backup of the project file"""
    print(f"{BLUE}📦 Creating backup at {BACKUP_PATH}{ENDC}")
    with open(PROJECT_FILE, 'r') as f_src:
        with open(BACKUP_PATH, 'w') as f_dst:
            f_dst.write(f_src.read())
    print(f"{GREEN}✅ Backup created{ENDC}")

def get_ios_target_id():
    """Get the iOS target ID from the project file"""
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
    
    # Look for ShuttlX target
    target_match = re.search(r'(\w+) /\* ShuttlX \*/ = {[\s\S]*?isa = PBXNativeTarget', content)
    if not target_match:
        return None
    return target_match.group(1)

def get_file_ref_section(content):
    """Find the PBXFileReference section"""
    match = re.search(r'\/\* Begin PBXFileReference section \*\/\n([\s\S]*?)\/\* End PBXFileReference section \*\/', content)
    if not match:
        return None
    return match.group(1)

def get_build_file_section(content):
    """Find the PBXBuildFile section"""
    match = re.search(r'\/\* Begin PBXBuildFile section \*\/\n([\s\S]*?)\/\* End PBXBuildFile section \*\/', content)
    if not match:
        return None
    return match.group(1)

def get_sources_build_phase_for_target(content, target_id):
    """Get the sources build phase ID for the given target"""
    target_section = re.search(rf'{target_id} /\* ShuttlX \*/ = {{[\s\S]*?buildPhases = \(([\s\S]*?)\);', content)
    if not target_section:
        return None
    
    build_phases = target_section.group(1)
    sources_phase = re.search(r'(\w+) /\* Sources \*/', build_phases)
    if not sources_phase:
        return None
    
    return sources_phase.group(1)

def get_sources_build_phase_content(content, phase_id):
    """Get the content of the sources build phase"""
    match = re.search(rf'{phase_id} /\* Sources \*/ = {{[\s\S]*?files = \(([\s\S]*?)\);', content)
    if not match:
        return None
    return match.group(1)

def add_files_to_project():
    """Add the missing Swift files to the project"""
    print(f"{HEADER}🔍 Adding missing Swift files to the project...{ENDC}")
    
    # Read the project file
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
    
    # Get iOS target ID
    target_id = get_ios_target_id()
    if not target_id:
        print(f"{RED}❌ Could not find iOS target ID{ENDC}")
        return False
    print(f"{BLUE}ℹ️ iOS target ID: {target_id}{ENDC}")
    
    # Get sources build phase ID
    sources_phase_id = get_sources_build_phase_for_target(content, target_id)
    if not sources_phase_id:
        print(f"{RED}❌ Could not find sources build phase for iOS target{ENDC}")
        return False
    print(f"{BLUE}ℹ️ Sources build phase ID: {sources_phase_id}{ENDC}")
    
    # Get file references section
    file_ref_section = get_file_ref_section(content)
    if not file_ref_section:
        print(f"{RED}❌ Could not find PBXFileReference section{ENDC}")
        return False
    
    # Get build file section
    build_file_section = get_build_file_section(content)
    if not build_file_section:
        print(f"{RED}❌ Could not find PBXBuildFile section{ENDC}")
        return False
    
    # Check if the files are already referenced
    file_references = {}
    build_files = {}
    
    for file_path in MISSING_FILES:
        file_name = os.path.basename(file_path)
        
        # Check if file reference already exists
        file_ref_match = re.search(rf'(\w+) /\* {file_name} \*/ = {{.*?path = {file_name}', file_ref_section)
        if file_ref_match:
            file_ref_id = file_ref_match.group(1)
            print(f"{YELLOW}⚠️ File reference already exists for {file_name}: {file_ref_id}{ENDC}")
        else:
            file_ref_id = str(uuid.uuid4()).upper().replace('-', '')[:24]
        
        file_references[file_name] = file_ref_id
        
        # Check if build file already exists
        build_file_match = re.search(rf'(\w+) /\* {file_name} in Sources \*/ = {{.*?fileRef = {file_ref_id}', build_file_section)
        if build_file_match:
            build_file_id = build_file_match.group(1)
            print(f"{YELLOW}⚠️ Build file already exists for {file_name}: {build_file_id}{ENDC}")
        else:
            build_file_id = str(uuid.uuid4()).upper().replace('-', '')[:24]
        
        build_files[file_name] = build_file_id
    
    # Get the sources build phase content
    sources_phase_content = get_sources_build_phase_content(content, sources_phase_id)
    if not sources_phase_content:
        print(f"{RED}❌ Could not find content of sources build phase{ENDC}")
        return False
    
    # Check if files are already in the sources build phase
    files_to_add = []
    for file_path in MISSING_FILES:
        file_name = os.path.basename(file_path)
        build_file_id = build_files[file_name]
        
        if build_file_id not in sources_phase_content:
            files_to_add.append((file_name, build_file_id))
    
    if not files_to_add:
        print(f"{GREEN}✅ All files are already in the sources build phase{ENDC}")
        return True
    
    # Add file references if needed
    for file_path in MISSING_FILES:
        file_name = os.path.basename(file_path)
        file_ref_id = file_references[file_name]
        
        # Add file reference if it doesn't exist
        file_ref_match = re.search(rf'{file_ref_id} /\* {file_name} \*/ = {{', content)
        if not file_ref_match:
            file_ref_entry = f'\t\t{file_ref_id} /* {file_name} */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; name = {file_name}; path = {file_name}; sourceTree = "<group>"; }};\n'
            content = re.sub(r'\/\* Begin PBXFileReference section \*\/\n', f'/* Begin PBXFileReference section */\n{file_ref_entry}', content)
            print(f"{GREEN}✅ Added file reference for {file_name}{ENDC}")
    
    # Add build files if needed
    for file_path in MISSING_FILES:
        file_name = os.path.basename(file_path)
        file_ref_id = file_references[file_name]
        build_file_id = build_files[file_name]
        
        # Add build file if it doesn't exist
        build_file_match = re.search(rf'{build_file_id} /\* {file_name} in Sources \*/ = {{', content)
        if not build_file_match:
            build_file_entry = f'\t\t{build_file_id} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {file_name} */; }};\n'
            content = re.sub(r'\/\* Begin PBXBuildFile section \*\/\n', f'/* Begin PBXBuildFile section */\n{build_file_entry}', content)
            print(f"{GREEN}✅ Added build file for {file_name}{ENDC}")
    
    # Add files to sources build phase
    for file_name, build_file_id in files_to_add:
        # Find the sources build phase and add the files
        source_phase_pattern = rf'({sources_phase_id} /\* Sources \*/ = {{\n.*?files = \()'
        if re.search(source_phase_pattern, content, re.DOTALL):
            # If there are already files in the phase, add a comma after the last one
            if re.search(rf'{sources_phase_id} /\* Sources \*/ = {{\n.*?files = \(\n([^)]+)', content, re.DOTALL):
                content = re.sub(r'(\n\t\t\t\t\w+ /\* .* in Sources \*/,?)(\n\t\t\t\);)', f'\\1,\n\t\t\t\t{build_file_id} /* {file_name} in Sources */\\2', content)
            else:
                content = re.sub(rf'({sources_phase_id} /\* Sources \*/ = {{\n.*?files = \(\n)(\t\t\t\);)', f'\\1\t\t\t\t{build_file_id} /* {file_name} in Sources */\n\\2', content)
            print(f"{GREEN}✅ Added {file_name} to sources build phase{ENDC}")
    
    # Write the updated content back to the project file
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)
    
    print(f"{GREEN}✅ Updated project file with missing Swift files{ENDC}")
    return True

def group_files_in_views_folder():
    """Ensure files are grouped in the Views folder in the project navigator"""
    print(f"{HEADER}🔍 Checking file organization in Views folder...{ENDC}")
    
    # Read the project file
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()
    
    # Find the Views group
    views_group_match = re.search(r'(\w+) /\* Views \*/ = {[\s\S]*?isa = PBXGroup', content)
    if not views_group_match:
        print(f"{YELLOW}⚠️ Views group not found, skipping group organization{ENDC}")
        return
    
    views_group_id = views_group_match.group(1)
    print(f"{BLUE}ℹ️ Views group ID: {views_group_id}{ENDC}")
    
    # Find the children of the Views group
    views_children_match = re.search(rf'{views_group_id} /\* Views \*/ = {{[\s\S]*?children = \(([\s\S]*?)\);', content)
    if not views_children_match:
        print(f"{YELLOW}⚠️ Could not find Views group children, skipping group organization{ENDC}")
        return
    
    views_children = views_children_match.group(1)
    
    # Check if the files are already in the Views group
    files_to_add_to_group = []
    for file_path in MISSING_FILES:
        file_name = os.path.basename(file_path)
        file_ref_id = None
        
        # Find the file reference ID
        file_ref_match = re.search(rf'(\w+) /\* {file_name} \*/ = {{.*?path = {file_name}', content)
        if file_ref_match:
            file_ref_id = file_ref_match.group(1)
        
        if file_ref_id and file_ref_id not in views_children:
            files_to_add_to_group.append((file_name, file_ref_id))
    
    if not files_to_add_to_group:
        print(f"{GREEN}✅ All files are already in the Views group{ENDC}")
        return
    
    # Add the files to the Views group
    for file_name, file_ref_id in files_to_add_to_group:
        # Add the file to the Views group's children
        pattern = rf'({views_group_id} /\* Views \*/ = {{[\s\S]*?children = \()'
        if re.search(pattern, content):
            if re.search(rf'{views_group_id} /\* Views \*/ = {{[\s\S]*?children = \(\n([^)]+)', content):
                content = re.sub(r'(\n\t\t\t\t\w+ /\* .* \*/,?)(\n\t\t\t\);)', f'\\1,\n\t\t\t\t{file_ref_id} /* {file_name} */\\2', content)
            else:
                content = re.sub(rf'({views_group_id} /\* Views \*/ = {{[\s\S]*?children = \(\n)(\t\t\t\);)', f'\\1\t\t\t\t{file_ref_id} /* {file_name} */\n\\2', content)
            print(f"{GREEN}✅ Added {file_name} to Views group in project navigator{ENDC}")
    
    # Write the updated content back to the project file
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)

def main():
    print(f"{HEADER}🛠️  ShuttlX Missing Swift Files Fixer{ENDC}")
    print(f"{HEADER}{'=' * 40}{ENDC}")
    
    # Create a backup of the project file
    create_backup()
    
    # Add missing files to the project
    success = add_files_to_project()
    if success:
        # Organize files in Views folder
        group_files_in_views_folder()
        
        print(f"\n{GREEN}{BOLD}✅ Successfully added missing Swift files to the project!{ENDC}")
        print(f"\n{YELLOW}📋 Next steps:{ENDC}")
        print(f"{YELLOW}1. Run the build script:{ENDC}")
        print(f"   ./tests/build_and_test_both_platforms.sh --ios-only --build")
        print(f"{YELLOW}2. If build still fails, restore from backup:{ENDC}")
        print(f"   cp {BACKUP_PATH} {PROJECT_FILE}")
        print(f"{YELLOW}3. Then try manual steps in Xcode{ENDC}")
    else:
        print(f"\n{RED}{BOLD}❌ Failed to add missing Swift files to the project{ENDC}")
        print(f"\n{YELLOW}Please try manual steps in Xcode:{ENDC}")
        print(f"1. Open ShuttlX.xcodeproj in Xcode")
        print(f"2. Right-click on the Views folder in the iOS target")
        print(f"3. Select 'Add Files to ShuttlX...'")
        print(f"4. Navigate to and select the missing Swift files")

if __name__ == "__main__":
    main()
