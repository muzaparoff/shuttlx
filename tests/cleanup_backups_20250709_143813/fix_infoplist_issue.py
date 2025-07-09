#!/usr/bin/env python3

"""
Fix duplicate Info.plist reference in Xcode project file
"""

import os
import re
import sys

def main():
    # Path to the project file
    project_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    project_file = os.path.join(project_path, "ShuttlX.xcodeproj", "project.pbxproj")
    
    print(f"🔍 Checking project file: {project_file}")
    
    if not os.path.exists(project_file):
        print(f"❌ Error: Project file not found at {project_file}")
        sys.exit(1)
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Create a backup
    backup_file = project_file + ".infoplist_backup"
    with open(backup_file, 'w') as f:
        f.write(content)
    print(f"✅ Created backup at {backup_file}")
    
    # Find the build phase sections
    sections = re.findall(r'(/\* Begin PBXResourcesBuildPhase section \*/.*?/\* End PBXResourcesBuildPhase section \*/)', content, re.DOTALL)
    
    if not sections:
        print("❌ No PBXResourcesBuildPhase section found")
        sys.exit(1)
    
    # Search for Info.plist references in the resources section
    modified = False
    for i, section in enumerate(sections):
        if "Info.plist" in section:
            print(f"📋 Found Info.plist reference in section {i+1}")
            
            # Extract and process each resource build phase in the section
            build_phases = re.findall(r'(\w{24}) /\* Resources \*/ = {.*?files = \(\s*(.*?)\s*\);', section, re.DOTALL)
            
            for phase_id, files in build_phases:
                if "Info.plist" in files:
                    print(f"🔍 Found Info.plist in build phase {phase_id}")
                    
                    # Process each file reference
                    file_refs = re.findall(r'(\w{24}) /\* .*?Info\.plist.*? in Resources \*/', files)
                    
                    if file_refs:
                        print(f"🔧 Need to remove {len(file_refs)} Info.plist references")
                        modified_content = content
                        
                        for ref in file_refs:
                            patterns = [
                                f"{ref} /\\* Info\\.plist in Resources \\*/,\\s*",
                                f"{ref} /\\* .*?Info\\.plist.*? in Resources \\*/,\\s*"
                            ]
                            
                            for pattern in patterns:
                                updated = re.sub(pattern, "", modified_content)
                                if updated != modified_content:
                                    modified_content = updated
                                    print(f"  ✓ Removed reference: {ref}")
                                    modified = True
                        
                        if modified:
                            content = modified_content
    
    if not modified:
        print("✅ No Info.plist references found in Resources build phases")
        return
    
    # Write the modified content back to the project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Successfully removed Info.plist from Copy Bundle Resources")
    print("🔄 Please clean and rebuild the project")

if __name__ == "__main__":
    main()
