#!/usr/bin/env python3
"""
Remove deleted backup files from iOS Sources build phase
"""

import os
import re
import shutil
from datetime import datetime

def create_backup(project_file):
    """Create a backup of the project file"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"{project_file}.backup_cleanup_{timestamp}"
    shutil.copy2(project_file, backup_file)
    print(f"✅ Created backup: {backup_file}")
    return backup_file

def remove_deleted_files_from_sources(project_file):
    """Remove references to deleted backup files from the Sources build phase"""
    
    # Read project file
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("🗑️ Removing references to deleted backup files...")
    
    # Files that were deleted
    deleted_files = [
        'ContentView_backup.swift',
        'ContentView_clean.swift'
    ]
    
    removed_count = 0
    
    for file_name in deleted_files:
        # Remove PBXBuildFile entries
        build_file_pattern = rf'\t\t[A-Z0-9]{{8}} /\* {re.escape(file_name)} in Sources \*/ = \{{[^}}]*\}};\n'
        matches = re.findall(build_file_pattern, content)
        if matches:
            content = re.sub(build_file_pattern, '', content)
            print(f"   ✅ Removed PBXBuildFile for {file_name}")
            removed_count += len(matches)
        
        # Remove from Sources build phase files array
        sources_pattern = rf'\t\t\t\t[A-Z0-9]{{8}} /\* {re.escape(file_name)} in Sources \*/,\n'
        matches = re.findall(sources_pattern, content)
        if matches:
            content = re.sub(sources_pattern, '', content)
            print(f"   ✅ Removed from Sources build phase: {file_name}")
            removed_count += len(matches)
        
        # Remove PBXFileReference entries  
        file_ref_pattern = rf'\t\t[A-Z0-9]{{8}} /\* {re.escape(file_name)} \*/ = \{{[^}}]*\}};\n'
        matches = re.findall(file_ref_pattern, content)
        if matches:
            content = re.sub(file_ref_pattern, '', content)
            print(f"   ✅ Removed PBXFileReference for {file_name}")
            removed_count += len(matches)
    
    # Write updated content
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Removed {removed_count} total references to deleted backup files")
    return removed_count > 0

def main():
    # Get the project directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_file = os.path.join(script_dir, "ShuttlX.xcodeproj", "project.pbxproj")
    
    if not os.path.exists(project_file):
        print(f"❌ Project file not found: {project_file}")
        return
    
    print("🧹 Cleanup: Remove Deleted Backup Files from Project")
    print("=" * 55)
    
    # Create backup
    backup_file = create_backup(project_file)
    
    try:
        # Remove references to deleted files
        if remove_deleted_files_from_sources(project_file):
            print("✅ Successfully cleaned up project file!")
        else:
            print("ℹ️ No references to deleted files found")
    
    except Exception as e:
        print(f"❌ Error: {e}")
        # Restore backup
        shutil.copy2(backup_file, project_file)
        print(f"📦 Restored backup from {backup_file}")

if __name__ == "__main__":
    main()
