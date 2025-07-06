#!/usr/bin/env python3
"""
Fix duplicate build file references in Xcode project
This script removes duplicate entries in the PBXBuildFile and build phases
"""

import re
import sys
from pathlib import Path

def fix_duplicate_build_files(project_path):
    """Fix duplicate build file references in project.pbxproj"""
    
    with open(project_path, 'r') as f:
        content = f.read()
    
    print("🔧 Fixing duplicate build file references...")
    
    # Track what we've seen to avoid duplicates
    seen_build_files = set()
    seen_file_refs = set()
    
    lines = content.split('\n')
    fixed_lines = []
    
    # First pass: identify and keep only one instance of each build file
    for line in lines:
        # Check for PBXBuildFile entries
        build_file_match = re.search(r'(\w+) /\* (\w+\.swift) in Sources \*/ = \{isa = PBXBuildFile; fileRef = (\w+)', line)
        if build_file_match:
            build_id, filename, file_ref = build_file_match.groups()
            key = f"{filename}_{file_ref}"
            
            if key in seen_build_files:
                print(f"  ❌ Removing duplicate build file: {filename}")
                continue  # Skip this duplicate
            else:
                seen_build_files.add(key)
                print(f"  ✅ Keeping build file: {filename}")
        
        # Check for file reference entries
        file_ref_match = re.search(r'(\w+) /\* (\w+\.swift) \*/ = \{isa = PBXFileReference.*path = "?([^"]*)"?', line)
        if file_ref_match:
            ref_id, filename, path = file_ref_match.groups()
            key = f"{filename}_{path}"
            
            if key in seen_file_refs:
                print(f"  ❌ Removing duplicate file ref: {filename} at {path}")
                continue  # Skip this duplicate
            else:
                seen_file_refs.add(key)
                print(f"  ✅ Keeping file ref: {filename}")
        
        fixed_lines.append(line)
    
    # Second pass: clean up build phases to remove references to deleted build files
    final_content = '\n'.join(fixed_lines)
    
    # Remove any remaining duplicate entries in build phases
    final_content = re.sub(r'\s*5GAGFNIH /\* ContentView\.swift in Sources \*/,?\s*\n', '', final_content)
    final_content = re.sub(r'\s*71909D46 /\* ContentView\.swift in Sources \*/,?\s*\n', '', final_content)
    
    # Write the fixed content
    with open(project_path, 'w') as f:
        f.write(final_content)
    
    print("✅ Fixed duplicate build file references")

def main():
    project_path = Path("ShuttlX.xcodeproj/project.pbxproj")
    
    if not project_path.exists():
        print(f"❌ Project file not found: {project_path}")
        sys.exit(1)
    
    # Create backup
    backup_path = project_path.with_suffix('.pbxproj.backup_fix_duplicates')
    with open(project_path, 'r') as src, open(backup_path, 'w') as dst:
        dst.write(src.read())
    print(f"📋 Created backup: {backup_path}")
    
    try:
        fix_duplicate_build_files(project_path)
        print("🎉 Successfully fixed Xcode project duplicates!")
    except Exception as e:
        print(f"❌ Error fixing project: {e}")
        # Restore backup
        with open(backup_path, 'r') as src, open(project_path, 'w') as dst:
            dst.write(src.read())
        print("🔄 Restored backup due to error")
        sys.exit(1)

if __name__ == "__main__":
    main()
