#!/usr/bin/env python3
"""
Add missing view files to Xcode project
"""

import os
import re
import shutil
from datetime import datetime

def add_files_to_xcode_project(project_dir):
    """Add missing view files to the Xcode project"""
    
    project_path = os.path.join(project_dir, "ShuttlX.xcodeproj", "project.pbxproj")
    
    if not os.path.exists(project_path):
        print(f"❌ Project file not found: {project_path}")
        return False
    
    # Create backup
    backup_path = f"{project_path}.backup_add_views_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(project_path, backup_path)
    print(f"✅ Created backup: {backup_path}")
    
    # Read the project file
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Files that need to be added
    view_files = [
        "WorkoutDashboardView.swift",
        "StatsView.swift", 
        "ProfileView.swift",
        "WorkoutSelectionView.swift",
        "OnboardingView.swift",
        "SettingsView.swift",
        "NotificationsView.swift"
    ]
    
    print(f"📁 Adding {len(view_files)} view files to project...")
    
    # Generate UUIDs for new files (using simple incremental approach)
    import random
    
    for filename in view_files:
        # Check if file exists on disk
        file_path = os.path.join(project_dir, "ShuttlX", "Views", filename)
        if not os.path.exists(file_path):
            print(f"⚠️  Skipping {filename} - file not found on disk")
            continue
            
        # Generate UUIDs
        file_ref_uuid = f"{random.randint(100000000000, 999999999999):012X}"
        build_file_uuid = f"{random.randint(100000000000, 999999999999):012X}"
        
        # Add PBXFileReference
        file_ref_entry = f"\t\t{file_ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
        
        # Add PBXBuildFile  
        build_file_entry = f"\t\t{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};\n"
        
        # Find the PBXFileReference section and add our file
        file_ref_pattern = r'(/\* Begin PBXFileReference section \*/.*?)(/\* End PBXFileReference section \*/)'
        match = re.search(file_ref_pattern, content, re.DOTALL)
        if match:
            content = content.replace(match.group(2), file_ref_entry + match.group(2))
            print(f"   ✅ Added file reference for {filename}")
        
        # Find the PBXBuildFile section and add our file
        build_file_pattern = r'(/\* Begin PBXBuildFile section \*/.*?)(/\* End PBXBuildFile section \*/)'
        match = re.search(build_file_pattern, content, re.DOTALL)
        if match:
            content = content.replace(match.group(2), build_file_entry + match.group(2))
            print(f"   ✅ Added build file for {filename}")
        
        # Add to Sources build phase
        sources_pattern = r'(/\* Sources \*/ = \{[^}]*files = \([^)]*?)(\s*\);)'
        match = re.search(sources_pattern, content, re.DOTALL)
        if match:
            sources_entry = f"\t\t\t\t{build_file_uuid} /* {filename} in Sources */,\n"
            content = content.replace(match.group(2), sources_entry + match.group(2))
            print(f"   ✅ Added to Sources build phase for {filename}")
        
        # Add to Views group
        views_group_pattern = r'(Views = \{[^}]*children = \([^)]*?)(\s*\);)'
        match = re.search(views_group_pattern, content, re.DOTALL)
        if match:
            group_entry = f"\t\t\t\t{file_ref_uuid} /* {filename} */,\n"
            content = content.replace(match.group(2), group_entry + match.group(2))
            print(f"   ✅ Added to Views group for {filename}")
    
    # Write the updated content back
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\n✅ Successfully added view files to Xcode project!")
    return True

if __name__ == "__main__":
    project_dir = "/Users/sergey/Documents/github/shuttlx"
    success = add_files_to_xcode_project(project_dir)
    
    if success:
        print("\n🎉 View files added to project!")
        print("✅ You can now try building the project in Xcode.")
        print("📝 Make sure to clean and rebuild the project (Cmd+Shift+K, then Cmd+B)")
    else:
        print("\n❌ Failed to add view files!")
