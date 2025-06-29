#!/usr/bin/env python3
"""
Careful fix for iOS Sources build phase - properly handles existing file references
"""

import os
import re
import shutil
from datetime import datetime

def create_backup(project_file):
    """Create a backup of the project file"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"{project_file}.backup_careful_fix_{timestamp}"
    shutil.copy2(project_file, backup_file)
    print(f"✅ Created backup: {backup_file}")
    return backup_file

def find_ios_swift_files(base_dir):
    """Find all Swift files in the iOS target directory"""
    ios_dir = os.path.join(base_dir, "ShuttlX")
    swift_files = []
    
    if os.path.exists(ios_dir):
        for root, dirs, files in os.walk(ios_dir):
            for file in files:
                if file.endswith('.swift'):
                    full_path = os.path.join(root, file)
                    relative_path = os.path.relpath(full_path, base_dir)
                    swift_files.append(relative_path)
    
    swift_files.sort()
    return swift_files

def generate_file_id():
    """Generate a unique file ID for Xcode project"""
    import random
    import string
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))

def extract_existing_references(content):
    """Extract all existing PBXFileReference and PBXBuildFile entries"""
    
    # Find all PBXFileReference entries
    file_ref_pattern = r'([A-Z0-9]{8}) /\* ([^*]+) \*/ = \{[^}]*path = "([^"]+)"[^}]*\};'
    file_refs = {}
    for match in re.finditer(file_ref_pattern, content):
        file_id, comment, path = match.groups()
        file_refs[path] = file_id
        print(f"   Found file ref: {file_id} -> {path}")
    
    # Find all PBXBuildFile entries
    build_file_pattern = r'([A-Z0-9]{8}) /\* ([^*]+) in Sources \*/ = \{[^}]*fileRef = ([A-Z0-9]{8})[^}]*\};'
    build_files = {}
    for match in re.finditer(build_file_pattern, content):
        build_id, comment, file_ref_id = match.groups()
        build_files[file_ref_id] = build_id
        print(f"   Found build file: {build_id} -> {file_ref_id}")
    
    return file_refs, build_files

def fix_ios_sources_careful(project_file, base_dir):
    """Carefully add all iOS Swift files to the iOS Sources build phase"""
    
    # Find all iOS Swift files
    ios_files = find_ios_swift_files(base_dir)
    print(f"📁 Found {len(ios_files)} iOS Swift files:")
    for file in ios_files:
        print(f"   - {file}")
    
    # Read project file
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("\n🔍 Analyzing existing references...")
    file_refs, build_files = extract_existing_references(content)
    
    # Find the iOS Sources build phase (A59234DA)
    ios_sources_pattern = r'(A59234DA /\* Sources \*/ = \{[^}]*files = \([^)]*)\);'
    match = re.search(ios_sources_pattern, content, re.DOTALL)
    
    if not match:
        print("❌ Could not find iOS Sources build phase (A59234DA)")
        return False
    
    print("✅ Found iOS Sources build phase")
    existing_sources_content = match.group(1)
    
    # Extract currently referenced build files in Sources phase
    current_build_refs = re.findall(r'([A-Z0-9]{8}) /\* ([^*]+) in Sources \*/', existing_sources_content)
    current_build_ids = {build_id for build_id, _ in current_build_refs}
    print(f"📄 Current build files in Sources: {len(current_build_ids)}")
    
    # Prepare new entries
    new_build_file_entries = []
    new_file_ref_entries = []
    new_sources_entries = []
    
    for swift_file in ios_files:
        filename = os.path.basename(swift_file)
        
        # Check if we have a file reference for this file
        file_ref_id = None
        
        # Look for exact path match first
        if swift_file in file_refs:
            file_ref_id = file_refs[swift_file]
        else:
            # Look for filename match
            for path, ref_id in file_refs.items():
                if os.path.basename(path) == filename:
                    file_ref_id = ref_id
                    break
        
        # If no file reference exists, create one
        if not file_ref_id:
            file_ref_id = generate_file_id()
            new_file_ref_entries.append(
                f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{swift_file}"; sourceTree = "<group>"; }};'
            )
            print(f"   Creating new file ref: {file_ref_id} -> {swift_file}")
        else:
            print(f"   Using existing file ref: {file_ref_id} -> {swift_file}")
        
        # Check if we have a build file for this file reference
        build_file_id = build_files.get(file_ref_id)
        
        # If no build file exists, create one
        if not build_file_id:
            build_file_id = generate_file_id()
            new_build_file_entries.append(
                f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};'
            )
            print(f"   Creating new build file: {build_file_id} -> {file_ref_id}")
        else:
            print(f"   Using existing build file: {build_file_id} -> {file_ref_id}")
        
        # Add to Sources build phase if not already there
        if build_file_id not in current_build_ids:
            new_sources_entries.append(f'\t\t\t\t{build_file_id} /* {filename} in Sources */,')
            print(f"   Adding to Sources: {build_file_id}")
        else:
            print(f"   Already in Sources: {build_file_id}")
    
    # Insert new PBXFileReference entries if needed
    if new_file_ref_entries:
        file_refs_pattern = r'(/\* Begin PBXFileReference section \*/)'
        file_refs_match = re.search(file_refs_pattern, content)
        if file_refs_match:
            insert_pos = file_refs_match.end()
            new_file_refs_text = '\n' + '\n'.join(new_file_ref_entries) + '\n'
            content = content[:insert_pos] + new_file_refs_text + content[insert_pos:]
            print(f"✅ Added {len(new_file_ref_entries)} new PBXFileReference entries")
    
    # Insert new PBXBuildFile entries if needed
    if new_build_file_entries:
        build_files_pattern = r'(/\* Begin PBXBuildFile section \*/)'
        build_files_match = re.search(build_files_pattern, content)
        if build_files_match:
            insert_pos = build_files_match.end()
            new_build_files_text = '\n' + '\n'.join(new_build_file_entries) + '\n'
            content = content[:insert_pos] + new_build_files_text + content[insert_pos:]
            print(f"✅ Added {len(new_build_file_entries)} new PBXBuildFile entries")
    
    # Update the iOS Sources build phase if needed
    if new_sources_entries:
        new_sources_content = existing_sources_content + ',\n' + '\n'.join(new_sources_entries)
        content = re.sub(ios_sources_pattern, new_sources_content + ');', content, flags=re.DOTALL)
        print(f"✅ Added {len(new_sources_entries)} files to iOS Sources build phase")
    
    # Write updated content
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ iOS Sources build phase updated successfully!")
    return True

def main():
    # Get the project directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_file = os.path.join(script_dir, "ShuttlX.xcodeproj", "project.pbxproj")
    
    if not os.path.exists(project_file):
        print(f"❌ Project file not found: {project_file}")
        return
    
    print("🔧 Careful iOS Sources Build Phase Fix")
    print("=" * 50)
    
    # Create backup
    backup_file = create_backup(project_file)
    
    try:
        # Fix the iOS Sources build phase
        if fix_ios_sources_careful(project_file, script_dir):
            print("✅ All iOS Swift files successfully added to Sources build phase!")
        else:
            print("❌ Failed to fix iOS Sources build phase")
            # Restore backup
            shutil.copy2(backup_file, project_file)
            print(f"📦 Restored backup from {backup_file}")
    
    except Exception as e:
        print(f"❌ Error: {e}")
        # Restore backup
        shutil.copy2(backup_file, project_file)
        print(f"📦 Restored backup from {backup_file}")

if __name__ == "__main__":
    main()
