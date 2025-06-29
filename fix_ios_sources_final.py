#!/usr/bin/env python3
"""
Final fix for iOS Sources build phase - adds all iOS Swift files to the correct Sources build phase
"""

import os
import re
import shutil
from datetime import datetime

def create_backup(project_file):
    """Create a backup of the project file"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"{project_file}.backup_final_fix_{timestamp}"
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

def fix_ios_sources_build_phase(project_file, base_dir):
    """Add all iOS Swift files to the iOS Sources build phase"""
    
    # Find all iOS Swift files
    ios_files = find_ios_swift_files(base_dir)
    print(f"📁 Found {len(ios_files)} iOS Swift files:")
    for file in ios_files:
        print(f"   - {file}")
    
    # Read project file
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find the iOS Sources build phase (A59234DA)
    ios_sources_pattern = r'(A59234DA /\* Sources \*/ = \{[^}]*files = \([^)]*)\);'
    match = re.search(ios_sources_pattern, content, re.DOTALL)
    
    if not match:
        print("❌ Could not find iOS Sources build phase (A59234DA)")
        return False
    
    print("✅ Found iOS Sources build phase")
    
    # Extract existing files in the Sources build phase
    existing_files_text = match.group(1)
    print(f"📄 Current Sources build phase content:\n{existing_files_text}\n")
    
    # Create new PBXBuildFile entries for each Swift file
    new_build_files = []
    new_file_references = []
    files_section_additions = []
    
    # Find existing file references to avoid duplicates
    existing_file_refs = re.findall(r'([A-Z0-9]{8}) /\* ([^*]+\.swift)', content)
    existing_refs_dict = {filepath: file_id for file_id, filepath in existing_file_refs}
    
    for swift_file in ios_files:
        filename = os.path.basename(swift_file)
        
        # Check if we already have a file reference for this file
        file_ref_id = None
        for existing_path, existing_id in existing_refs_dict.items():
            if existing_path == filename or existing_path.endswith(swift_file):
                file_ref_id = existing_id
                break
        
        # If no existing reference, create new ones
        if not file_ref_id:
            file_ref_id = generate_file_id()
            # Add to PBXFileReference section
            new_file_references.append(f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{swift_file}"; sourceTree = "<group>"; }};')
        
        # Create PBXBuildFile entry
        build_file_id = generate_file_id()
        new_build_files.append(f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};')
        
        # Add to files array in Sources build phase
        files_section_additions.append(f'\t\t\t\t{build_file_id} /* {filename} in Sources */,')
    
    # Insert new PBXBuildFile entries
    build_files_section_match = re.search(r'(/\* Begin PBXBuildFile section \*/)', content)
    if build_files_section_match:
        insert_pos = build_files_section_match.end()
        new_build_files_text = '\n' + '\n'.join(new_build_files) + '\n'
        content = content[:insert_pos] + new_build_files_text + content[insert_pos:]
        print(f"✅ Added {len(new_build_files)} PBXBuildFile entries")
    
    # Insert new PBXFileReference entries if needed
    if new_file_references:
        file_refs_section_match = re.search(r'(/\* Begin PBXFileReference section \*/)', content)
        if file_refs_section_match:
            insert_pos = file_refs_section_match.end()
            new_file_refs_text = '\n' + '\n'.join(new_file_references) + '\n'
            content = content[:insert_pos] + new_file_refs_text + content[insert_pos:]
            print(f"✅ Added {len(new_file_references)} PBXFileReference entries")
    
    # Update the iOS Sources build phase files array
    new_files_text = existing_files_text + ',\n' + '\n'.join(files_section_additions)
    content = re.sub(ios_sources_pattern, new_files_text + ');', content, flags=re.DOTALL)
    
    print(f"✅ Updated iOS Sources build phase with {len(files_section_additions)} files")
    
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
    
    print("🔧 Final iOS Sources Build Phase Fix")
    print("=" * 50)
    
    # Create backup
    backup_file = create_backup(project_file)
    
    try:
        # Fix the iOS Sources build phase
        if fix_ios_sources_build_phase(project_file, script_dir):
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
