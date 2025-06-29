#!/usr/bin/env python3
"""
Fix watchOS Target Missing Files
================================
This script specifically adds the missing ShuttlXWatchApp.swift and ContentView.swift
files to the watchOS target's Sources build phase.
"""

import os
import sys
import re
import uuid
from datetime import datetime

def generate_xcode_id():
    """Generate a unique 24-character alphanumeric ID for Xcode"""
    return ''.join([format(int.from_bytes(os.urandom(3), 'big'), '06X') for _ in range(4)])

def backup_project_file(project_path):
    """Create a backup of the project file"""
    backup_path = f"{project_path}.backup_watchos_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    with open(project_path, 'r') as src, open(backup_path, 'w') as dst:
        dst.write(src.read())
    print(f"📦 Backup created: {backup_path}")
    return backup_path

def find_watchos_files():
    """Find the missing watchOS files that need to be added"""
    watchos_dir = "ShuttlXWatch Watch App Watch App"
    files_to_add = []
    
    # Files that should be in the watchOS target
    expected_files = [
        "ShuttlXWatchApp.swift",
        "ContentView.swift"
    ]
    
    for filename in expected_files:
        filepath = os.path.join(watchos_dir, filename)
        if os.path.exists(filepath):
            files_to_add.append({
                'filename': filename,
                'filepath': filepath,
                'relative_path': filepath
            })
        else:
            print(f"⚠️  File not found: {filepath}")
    
    return files_to_add

def main():
    """Main function to fix watchOS target"""
    project_path = "ShuttlX.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_path):
        print(f"❌ Project file not found: {project_path}")
        return 1
    
    print("🔧 ShuttlX watchOS Target Fix")
    print("=" * 40)
    
    # Find files to add
    files_to_add = find_watchos_files()
    
    if not files_to_add:
        print("✅ No missing watchOS files found")
        return 0
    
    print(f"📋 Found {len(files_to_add)} missing watchOS files:")
    for file_info in files_to_add:
        print(f"  - {file_info['filename']}")
    
    # Create backup
    backup_path = backup_project_file(project_path)
    
    # Read current project file
    with open(project_path, 'r') as f:
        content = f.read()
    
    # watchOS target Sources build phase ID
    watchos_sources_phase_id = "A56D91042E0940ED00E19F06"
    
    # Add PBXFileReference entries
    print("📁 Adding PBXFileReference entries...")
    fileref_section_match = re.search(r'(/* Begin PBXFileReference section \*/.*?)(/* End PBXFileReference section \*/)', content, re.DOTALL)
    if not fileref_section_match:
        print("❌ Could not find PBXFileReference section")
        return 1
    
    new_filerefs = []
    for file_info in files_to_add:
        fileref_id = generate_xcode_id()
        file_info['fileref_id'] = fileref_id
        fileref_entry = f'\t\t{fileref_id} /* {file_info["filename"]} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_info["filename"]}; sourceTree = "<group>"; }};'
        new_filerefs.append(fileref_entry)
    
    # Insert file references
    fileref_content = fileref_section_match.group(1) + '\n'.join(new_filerefs) + '\n\t\t' + fileref_section_match.group(2)
    content = content.replace(fileref_section_match.group(0), fileref_content)
    
    # Add PBXBuildFile entries
    print("📝 Adding PBXBuildFile entries...")
    buildfile_section_match = re.search(r'(/* Begin PBXBuildFile section \*/.*?)(/* End PBXBuildFile section \*/)', content, re.DOTALL)
    if not buildfile_section_match:
        print("❌ Could not find PBXBuildFile section")
        return 1
    
    new_buildfiles = []
    for file_info in files_to_add:
        buildfile_id = generate_xcode_id()
        file_info['buildfile_id'] = buildfile_id
        buildfile_entry = f'\t\t{buildfile_id} /* {file_info["filename"]} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_info["fileref_id"]} /* {file_info["filename"]} */; }};'
        new_buildfiles.append(buildfile_entry)
    
    # Insert build files
    buildfile_content = buildfile_section_match.group(1) + '\n'.join(new_buildfiles) + '\n\t\t' + buildfile_section_match.group(2)
    content = content.replace(buildfile_section_match.group(0), buildfile_content)
    
    # Add files to watchOS Sources build phase
    print("⚡ Adding files to watchOS Sources build phase...")
    
    # Find the watchOS Sources build phase and update it
    sources_pattern = rf'({watchos_sources_phase_id} /\* Sources \*/ = {{\s*isa = PBXSourcesBuildPhase;\s*buildActionMask = 2147483647;\s*files = \()(.*?)(\);\s*runOnlyForDeploymentPostprocessing = 0;\s*}})'
    sources_match = re.search(sources_pattern, content, re.DOTALL)
    
    if not sources_match:
        print(f"❌ Could not find watchOS Sources build phase with ID {watchos_sources_phase_id}")
        return 1
    
    # Build the new files list
    current_files = sources_match.group(2).strip()
    new_files = []
    
    for file_info in files_to_add:
        new_files.append(f"{file_info['buildfile_id']} /* {file_info['filename']} in Sources */")
    
    if current_files:
        files_list = current_files + ',\n\t\t\t\t' + ',\n\t\t\t\t'.join(new_files)
    else:
        files_list = '\n\t\t\t\t' + ',\n\t\t\t\t'.join(new_files) + '\n\t\t\t'
    
    # Replace the Sources build phase
    new_sources_content = sources_match.group(1) + files_list + sources_match.group(3)
    content = content.replace(sources_match.group(0), new_sources_content)
    
    # Write the updated project file
    with open(project_path, 'w') as f:
        f.write(content)
    
    print("\n✅ Successfully added missing watchOS files:")
    for file_info in files_to_add:
        print(f"  ✅ {file_info['filename']} (FileRef: {file_info['fileref_id']}, BuildFile: {file_info['buildfile_id']})")
    
    print(f"\n🎉 watchOS target fix complete!")
    print(f"📦 Backup available at: {backup_path}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
