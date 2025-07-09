#!/usr/bin/env python3
import re
import os
import shutil
import subprocess

# Paths
project_path = '/Users/sergey/Documents/github/shuttlx/ShuttlX.xcodeproj/project.pbxproj'
backup_path = project_path + '.backup'

# Create backup
print(f"📦 Creating backup of project file at {backup_path}")
shutil.copy2(project_path, backup_path)

# Read the project file
with open(project_path, 'r') as f:
    content = f.read()

# Look for resources build phase section that contains Info.plist
print("🔍 Looking for resources build phase containing Info.plist...")

# Pattern to find resources build phase sections
resources_phase_pattern = r'(/\* Begin PBXResourcesBuildPhase section \*/.*?/\* End PBXResourcesBuildPhase section \*/)'
resources_section_match = re.search(resources_phase_pattern, content, re.DOTALL)

if resources_section_match:
    resources_section = resources_section_match.group(1)
    print("✅ Found resources build phase section")
    
    # Look for any section that includes Info.plist
    info_plist_pattern = r'([A-F0-9]+ /\* Resources \*/ = \{[^}]*?Info\.plist[^}]*?\};)'
    info_plist_match = re.search(info_plist_pattern, resources_section, re.DOTALL)
    
    if info_plist_match:
        info_plist_section = info_plist_match.group(1)
        print("🔎 Found Info.plist in resources section:")
        print(info_plist_section)
        
        # Remove the Info.plist file reference from this section
        modified_section = re.sub(r'[A-F0-9]+ /\* Info\.plist( in Resources)? \*/,?\s*', '', info_plist_section)
        content = content.replace(info_plist_section, modified_section)
        
        print("✅ Removed Info.plist from resources section")
    else:
        print("ℹ️ No Info.plist found in resources sections")
else:
    print("❌ Could not find resources build phase section")

# Also look for and remove null entries in Resources
print("\n🔍 Cleaning null entries in Resources sections...")
content = re.sub(r'[A-F0-9]+ /\* \(null\) in Resources \*/,?\s*', '', content)

# Check if there are any empty files = () sections and clean them
empty_files_pattern = r'files = \(\s*\);'
if re.search(empty_files_pattern, content):
    print("🧹 Cleaning empty files sections...")
    # No need to replace, these are valid

# Write the modified content back
with open(project_path, 'w') as f:
    f.write(content)

print("\n✅ Project file updated. Now running xcodeproj cleanup...")

# Run additional cleanup using plutil
try:
    print("\n🔧 Running plutil to normalize project file format...")
    subprocess.run(['plutil', '-convert', 'xml1', project_path], check=True)
    print("✅ Project file normalized")
except subprocess.CalledProcessError:
    print("⚠️ plutil command failed, but project file was still modified")

print("\n📋 Manual verification needed:")
print("1. Open ShuttlX.xcodeproj in Xcode")
print("2. Select ShuttlXWatch Watch App Watch App target")
print("3. Go to Build Phases tab")
print("4. Check that Info.plist is NOT in Copy Bundle Resources")
print("5. Clean the project and try building again")
print("\n✅ Script completed!")
