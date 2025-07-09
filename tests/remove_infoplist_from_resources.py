#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Fix the duplicate Info.plist issue by specifically addressing the error:
"Multiple commands produce '/Users/sergey/Documents/github/shuttlx/build/Release-iphonesimulator/ShuttlXWatch Watch App Watch App.app/Info.plist'"

The issue is that the Info.plist is both being processed as an Info.plist file and included in the
Copy Bundle Resources phase. This script removes the null references in the resources phase that
are causing the duplicate Info.plist error.

This script was created as part of Phase 18 to fix the build issue preventing the iOS app from
building successfully. The specific error was:
  - error: Multiple commands produce '[path]/ShuttlXWatch Watch App Watch App.app/Info.plist'
  - note: Target has copy command from '[path]/Info.plist' 
  - note: Target has process command with output '[path]/Info.plist'

The fix works by:
1. Finding null resource references in the PBXBuildFile section
2. Identifying resources build phases that contain these null references
3. Removing the null references from the resources phase
4. Also removing the null build file entries from the project file

Usage:
    ./tests/remove_infoplist_from_resources.py

After running this script, the build should succeed without the duplicate Info.plist error.
"""

import os
import re
import sys
from pathlib import Path

def main():
    print("🔧 ShuttlX - Remove null references from Resources phase")
    print("======================================================")

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

    # Find all null resource references in PBXBuildFile section
    null_resources = re.findall(r'(\w+) /\* \(null\) in Resources \*/ = {isa = PBXBuildFile; };', content)
    
    if not null_resources:
        print("❓ No null resources found in PBXBuildFile section")
        print("✅ No changes needed")
        return
    else:
        print(f"🔍 Found {len(null_resources)} null resource references: {', '.join(null_resources)}")
    
    # Create backup
    backup_path = str(project_file) + ".infoplist_duplicate_backup"
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(original_content)
    print(f"📂 Created backup at {backup_path}")
    
    # Remove null references from Resources build phase
    resources_phase_pattern = r'(\w+) /\* Resources \*/ = {\s*isa = PBXResourcesBuildPhase;.*?files = \((.*?)\);'
    resources_phases = re.findall(resources_phase_pattern, content, re.DOTALL)
    
    modified = False
    for phase_id, files_section in resources_phases:
        print(f"📋 Examining resources phase: {phase_id}")
        
        # Check for null references in this phase
        phase_modified = False
        modified_files_section = files_section
        
        for null_ref in null_resources:
            pattern = rf'{null_ref} /\* \(null\) in Resources \*/,?\s*'
            if re.search(pattern, files_section):
                modified_files_section = re.sub(pattern, '', modified_files_section)
                print(f"  ✅ Removed null reference {null_ref} from resources phase")
                phase_modified = True
                modified = True
        
        if phase_modified:
            # Update the content with modified files section
            old_section = f"files = ({files_section});"
            new_section = f"files = ({modified_files_section});"
            content = content.replace(old_section, new_section)
    
    # Also remove the null resource build file entries
    for null_ref in null_resources:
        pattern = rf'{null_ref} /\* \(null\) in Resources \*/ = {{isa = PBXBuildFile; }};'
        if re.search(pattern, content):
            content = re.sub(pattern, '', content)
            print(f"  ✅ Removed null build file entry {null_ref}")
            modified = True
    
    if not modified:
        print("❓ No changes were made to the project file")
        return
    
    # Write the modified content
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("\n✅ Successfully removed null references from resources phase")
    print("📋 This should fix the 'Multiple commands produce ... Info.plist' error")
    print("\n📝 Manual steps if build still fails:")
    print("  1. Open ShuttlX.xcodeproj in Xcode")
    print("  2. Select the ShuttlXWatch Watch App Watch App target")
    print("  3. Go to Build Phases tab")
    print("  4. Expand 'Copy Bundle Resources'")
    print("  5. Check if Info.plist is listed and remove it if present")
    print("  6. Clean and rebuild the project")

if __name__ == "__main__":
    main()
