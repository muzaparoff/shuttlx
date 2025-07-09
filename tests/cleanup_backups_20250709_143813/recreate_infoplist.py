#!/usr/bin/env python3
import os
import re
import subprocess
import shutil
import tempfile

# Define paths
project_path = '/Users/sergey/Documents/github/shuttlx/ShuttlX.xcodeproj/project.pbxproj'
backup_path = project_path + '.xml_backup'
temp_xml_path = tempfile.mktemp('.xml')

print(f"🔍 Starting XML-based Info.plist fix for Xcode project...")

# Create a backup
shutil.copy2(project_path, backup_path)
print(f"📦 Created backup at {backup_path}")

# Convert to XML for easier processing
try:
    print("🔄 Converting project file to XML format...")
    subprocess.run(['plutil', '-convert', 'xml1', '-o', temp_xml_path, project_path], check=True)
    print(f"✅ Converted to XML at {temp_xml_path}")
except subprocess.CalledProcessError:
    print("❌ Failed to convert project file to XML. Project file may be corrupted.")
    exit(1)

# Let's try a different approach - directly recreate the Info.plist file
info_plist_path = '/Users/sergey/Documents/github/shuttlx/ShuttlXWatch Watch App Watch App/Info.plist'
if not os.path.exists(info_plist_path):
    print(f"⚠️ Info.plist not found at {info_plist_path}, creating it...")
    
    # Create minimal Info.plist
    with open(info_plist_path, 'w') as f:
        f.write('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>ShuttlX Watch App</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>WKWatchKitApp</key>
    <true/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
    </array>
</dict>
</plist>''')
    print("✅ Created new Info.plist file")
else:
    print(f"✅ Info.plist exists at {info_plist_path}")

# Now let's just clean the derived data as a last resort
derived_data_dir = os.path.expanduser('~/Library/Developer/Xcode/DerivedData')
if os.path.exists(derived_data_dir):
    print("\n🧹 Cleaning Xcode DerivedData for ShuttlX...")
    shuttlx_derived_data = [os.path.join(derived_data_dir, d) for d in os.listdir(derived_data_dir) if 'ShuttlX-' in d]
    
    if shuttlx_derived_data:
        for path in shuttlx_derived_data:
            print(f"  Removing {path}")
            try:
                shutil.rmtree(path)
                print(f"  ✅ Removed {path}")
            except Exception as e:
                print(f"  ❌ Failed to remove {path}: {e}")
    else:
        print("  No ShuttlX derived data found")

print("\n📋 Final instructions:")
print("1. Open Xcode and close any open ShuttlX project")
print("2. Delete any ShuttlX derived data from Xcode menu: Product > Clean Build Folder")
print("3. Reopen ShuttlX.xcodeproj")
print("4. Select ShuttlXWatch Watch App Watch App target")
print("5. Go to Build Phases")
print("6. Open Copy Bundle Resources section")
print("7. If Info.plist is listed, delete it (with the - button)")
print("8. Build the project")
print("\n✅ Script completed!")
