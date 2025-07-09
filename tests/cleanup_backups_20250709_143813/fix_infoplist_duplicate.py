#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Fix Info.plist duplicate resource issue in Xcode project
This script removes Info.plist from Copy Bundle Resources phase to prevent duplication
"""

import os
import re
import sys
from pathlib import Path

def main():
    print("🔧 ShuttlX - Fix Info.plist Duplicate Resource")
    print("=============================================")

    # Find project file
    project_root = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    project_file = project_root / "ShuttlX.xcodeproj" / "project.pbxproj"

    if not project_file.exists():
        print(f"❌ Cannot find project file at {project_file}")
        sys.exit(1)

    print(f"📂 Found project file: {project_file}")
    
    # Load project file
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content

    # Find all resources build phases (Copy Bundle Resources)
    resources_phases = re.findall(r'\/\* Resources \*\/ = {\n\s*isa = PBXResourcesBuildPhase;.*?files = \((.*?)\);', content, re.DOTALL)
    
    if not resources_phases:
        print("❓ No Resources build phases found in project file")
        return
    
    # Check for Info.plist in any resources phase
    changed = False
    for i, phase in enumerate(resources_phases):
        if 'Info.plist' in phase:
            print(f"📋 Found Info.plist in Resources build phase #{i+1}")
            
            # Extract all file references in this phase
            file_refs = re.findall(r'(\w+) /\* (.*?) in Resources \*/', phase)
            
            # Find Info.plist references
            info_plist_refs = [ref for ref, name in file_refs if 'Info.plist' in name]
            
            if info_plist_refs:
                print(f"🔍 Found {len(info_plist_refs)} Info.plist references to remove")
                changed = True
                
                # Remove each Info.plist reference from the phase
                for ref in info_plist_refs:
                    patterns = [
                        rf'{ref} /\* Info\.plist in Resources \*/,\n',
                        rf'{ref} /\* Info\.plist in Resources \*/,',
                        rf'{ref} /\* .*?Info\.plist.*? in Resources \*/,\n',
                        rf'{ref} /\* .*?Info\.plist.*? in Resources \*/,'
                    ]
                    
                    for pattern in patterns:
                        if pattern in content:
                            content = content.replace(pattern, '')
                            print(f"  ✓ Removed reference: {ref}")
                            break
    
    if not changed:
        print("✅ No Info.plist references found in Copy Bundle Resources, no fix needed")
        return
    
    # Backup the original file
    backup_path = str(project_file) + ".infoplist_backup"
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(original_content)
    print(f"📂 Backup created: {backup_path}")
    
    # Write the modified content
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Info.plist references removed from Copy Bundle Resources phase")
    print("🚀 Project file updated successfully")
    print("📝 Note: You may need to clean the project before building again")
    
    print(f"📋 Found {len(matches)} Info.plist references in Copy Bundle Resources")
    
    # Replace the file references in the build phase
    for file_ref in matches:
        pattern = rf'{file_ref} /\* Info\.plist in Resources \*/,\n'
        content = content.replace(pattern, '')
        # Also try without trailing newline
        pattern = rf'{file_ref} /\* Info\.plist in Resources \*/,'
        content = content.replace(pattern, '')
        
        print(f"🔧 Removing reference: {file_ref}")
    
    if content == original_content:
        print("⚠️ No changes were made to the project file")
        return
    
    # Backup the original file
    backup_path = str(project_file) + ".infoplist_backup"
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(original_content)
    print(f"📂 Backup created: {backup_path}")
    
    # Write the modified content
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Info.plist references removed from Copy Bundle Resources phase")
    print("🚀 Project file updated successfully")
    print("📝 Note: You may need to clean the project before building again")

if __name__ == "__main__":
    main()
