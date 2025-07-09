#!/usr/bin/env python3
import os
import re
import shutil

# Define paths
project_path = '/Users/sergey/Documents/github/shuttlx/ShuttlX.xcodeproj/project.pbxproj'
backup_path = project_path + '.emergency_backup'
info_plist_path = '/Users/sergey/Documents/github/shuttlx/ShuttlXWatch Watch App Watch App/Info.plist'

print(f"🔍 Starting emergency Info.plist fix for Xcode project...")

# Create a backup
shutil.copy2(project_path, backup_path)
print(f"📦 Created backup at {backup_path}")

# Read project file
with open(project_path, 'r') as f:
    content = f.read()

original_content = content

# Step 1: Find any direct reference to Info.plist in PBXBuildFile section
print("👀 Looking for Info.plist reference in PBXBuildFile section...")
build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/(.*?)/\* End PBXBuildFile section \*/', content, re.DOTALL)

if build_file_section:
    build_file_content = build_file_section.group(1)
    info_plist_references = re.findall(r'([A-F0-9]+) /\* Info\.plist in .+ \*/', build_file_content)
    
    if info_plist_references:
        print(f"✅ Found {len(info_plist_references)} Info.plist references in PBXBuildFile section")
        for ref in info_plist_references:
            print(f"  - {ref}")
        
        # Remove each reference from PBXBuildFile section
        for ref in info_plist_references:
            pattern = rf'{ref} /\* Info\.plist in .+ \*/ = \{{[^}}]*\}};\s*'
            content = re.sub(pattern, '', content)
        
        print("✅ Removed Info.plist references from PBXBuildFile section")
    else:
        print("ℹ️ No Info.plist references found in PBXBuildFile section")
else:
    print("⚠️ Couldn't find PBXBuildFile section")

# Step 2: Find any references in resource build phases
print("\n👀 Looking for Info.plist in PBXResourcesBuildPhase section...")
resource_phase_pattern = r'/\* Begin PBXResourcesBuildPhase section \*/(.*?)/\* End PBXResourcesBuildPhase section \*/'
resource_section = re.search(resource_phase_pattern, content, re.DOTALL)

if resource_section:
    resource_content = resource_section.group(1)
    
    # Find all resource build phases
    build_phases = re.findall(r'([A-F0-9]+) /\* Resources \*/ = \{[^}]*?files = \([^)]*?\);[^}]*?\};', resource_content, re.DOTALL)
    
    if build_phases:
        print(f"✅ Found {len(build_phases)} resource build phases")
        
        for phase_id in build_phases:
            # Find the specific build phase
            phase_pattern = rf'{phase_id} /\* Resources \*/ = \{{[^}}]*?files = \([^)]*?\);[^}}]*?\}};'
            phase_match = re.search(phase_pattern, resource_content, re.DOTALL)
            
            if phase_match:
                phase_content = phase_match.group(0)
                
                if "Info.plist" in phase_content:
                    print(f"  - Phase {phase_id} contains Info.plist reference")
                    
                    # Remove Info.plist reference
                    modified_phase = re.sub(r'[A-F0-9]+ /\* Info\.plist( in Resources)? \*/,?\s*', '', phase_content)
                    content = content.replace(phase_content, modified_phase)
                    print(f"  ✅ Removed Info.plist from phase {phase_id}")
                
                # Also clean any null references
                if "(null)" in phase_content:
                    print(f"  - Phase {phase_id} contains null references")
                    modified_phase = re.sub(r'[A-F0-9]+ /\* \(null\)( in Resources)? \*/,?\s*', '', phase_content)
                    content = content.replace(phase_content, modified_phase)
                    print(f"  ✅ Cleaned null references from phase {phase_id}")
    else:
        print("ℹ️ No resource build phases found")
else:
    print("⚠️ Couldn't find PBXResourcesBuildPhase section")

# Step 3: Clean up any trailing commas in file lists
print("\n🧹 Cleaning up trailing commas in file lists...")
content = re.sub(r',(\s*\);)', r'\1', content)
print("✅ Cleaned up trailing commas")

# Write the updated content back if changes were made
if content != original_content:
    with open(project_path, 'w') as f:
        f.write(content)
    print("\n✅ Updated project file with fixes")
else:
    print("\nℹ️ No changes were needed in the project file")

print("\n📋 Please try building the project now. If it still fails:")
print("1. Restore the project from backup: cp", backup_path, project_path)
print("2. Open Xcode and manually remove Info.plist from Copy Bundle Resources")
