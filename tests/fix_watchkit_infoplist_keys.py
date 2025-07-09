#!/usr/bin/env python3
"""
fix_watchkit_infoplist_keys.py

This script checks and fixes WatchKit-related keys in Info.plist files to prevent
the "WatchKit app has both WKApplication and WKWatchKitApp Info.plist keys" error.

Usage:
    python3 fix_watchkit_infoplist_keys.py

The script will automatically:
1. Find all Info.plist files in watchOS app directories
2. Check for conflicting WKApplication and WKWatchKitApp keys
3. Remove the WKWatchKitApp key if both are present (keeping the modern WKApplication key)
4. Make a backup of any modified files

Author: GitHub Copilot
Date: July 9, 2025
"""

import os
import sys
import re
import shutil
import subprocess
import datetime
import plistlib

def find_infoplist_files(base_dir):
    """Find all Info.plist files in the project"""
    info_plist_files = []
    watch_dirs = []
    
    for root, dirs, files in os.walk(base_dir):
        for file in files:
            if file == 'Info.plist':
                # Check if this is in a Watch directory
                if 'Watch' in root:
                    watch_dirs.append(root)
                info_plist_files.append(os.path.join(root, file))
    
    return info_plist_files, watch_dirs

def is_binary_plist(file_path):
    """Check if the plist file is in binary format"""
    with open(file_path, 'rb') as f:
        header = f.read(8)
        return header[:6] == b'bplist'

def check_and_fix_watchkit_keys(plist_file):
    """Check for and fix conflicting WatchKit keys in an Info.plist file"""
    try:
        # Check if the file is a binary plist
        if is_binary_plist(plist_file):
            # Use plistlib for binary plists
            with open(plist_file, 'rb') as f:
                try:
                    plist_data = plistlib.load(f)
                    
                    # Check if both keys exist
                    has_wkapplication = 'WKApplication' in plist_data
                    has_wkwatchkitapp = 'WKWatchKitApp' in plist_data
                    
                    if has_wkapplication and has_wkwatchkitapp:
                        print(f"⚠️ Found both WKApplication and WKWatchKitApp keys in {plist_file}")
                        
                        # Create a backup
                        backup_file = f"{plist_file}.watchkit_keys_backup"
                        shutil.copy2(plist_file, backup_file)
                        print(f"📄 Created backup at {backup_file}")
                        
                        # Remove the WKWatchKitApp key
                        del plist_data['WKWatchKitApp']
                        
                        # Write back the modified plist
                        with open(plist_file, 'wb') as out_f:
                            plistlib.dump(plist_data, out_f)
                        
                        print(f"✅ Removed WKWatchKitApp key from {plist_file}")
                        return True
                except Exception as e:
                    print(f"⚠️ Error processing binary plist {plist_file}: {e}")
                    return False
        else:
            # Handle XML plists using regex
            with open(plist_file, 'r', encoding='utf-8', errors='ignore') as f:
                try:
                    content = f.read()
                    
                    # Check if both keys exist
                    has_wkapplication = '<key>WKApplication</key>' in content
                    has_wkwatchkitapp = '<key>WKWatchKitApp</key>' in content
                    
                    if has_wkapplication and has_wkwatchkitapp:
                        print(f"⚠️ Found both WKApplication and WKWatchKitApp keys in {plist_file}")
                        
                        # Create a backup
                        backup_file = f"{plist_file}.watchkit_keys_backup"
                        shutil.copy2(plist_file, backup_file)
                        print(f"📄 Created backup at {backup_file}")
                        
                        # Remove the WKWatchKitApp key and value (typically <true/>)
                        pattern = r'\s*<key>WKWatchKitApp</key>\s*\n\s*<true/>'
                        new_content = re.sub(pattern, '', content)
                        
                        with open(plist_file, 'w', encoding='utf-8') as out_f:
                            out_f.write(new_content)
                        
                        print(f"✅ Removed WKWatchKitApp key from {plist_file}")
                        return True
                except Exception as e:
                    print(f"⚠️ Error processing XML plist {plist_file}: {e}")
                    return False
    except Exception as e:
        print(f"⚠️ Error processing file {plist_file}: {e}")
        return False
    
    return False

def check_specific_file(file_path):
    """Check and fix a specific Info.plist file"""
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return False
    
    print(f"🔍 Checking specific file: {file_path}")
    return check_and_fix_watchkit_keys(file_path)

def main():
    """Main function to check and fix WatchKit Info.plist keys"""
    # Get the project root directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)  # Assumes script is in /tests directory
    
    # Check if a specific file was provided as an argument
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
        # If a relative path is provided, make it absolute
        if not os.path.isabs(file_path):
            file_path = os.path.abspath(os.path.join(project_dir, file_path))
        return check_specific_file(file_path)
    
    print(f"🔍 Searching for Info.plist files in {project_dir}...")
    
    try:
        info_plist_files, watch_dirs = find_infoplist_files(project_dir)
        
        if not watch_dirs:
            print("❓ No Watch app directories found.")
            return
        
        print(f"📱 Found {len(watch_dirs)} Watch app directories:")
        for watch_dir in watch_dirs:
            print(f"  - {os.path.relpath(watch_dir, project_dir)}")
        
        # Focus on ShuttlXWatch Watch App Watch App/Info.plist first
        main_watch_app_plist = os.path.join(project_dir, "ShuttlXWatch Watch App Watch App", "Info.plist")
        if os.path.exists(main_watch_app_plist):
            print(f"🎯 Checking main watchOS app Info.plist first: {main_watch_app_plist}")
            check_and_fix_watchkit_keys(main_watch_app_plist)
        
        fixed_files = 0
        
        for plist_file in info_plist_files:
            if any(watch_dir in plist_file for watch_dir in watch_dirs):
                if plist_file != main_watch_app_plist:  # Skip if already processed
                    try:
                        if check_and_fix_watchkit_keys(plist_file):
                            fixed_files += 1
                    except Exception as e:
                        print(f"❌ Error processing {plist_file}: {str(e)}")
        
        if fixed_files > 0:
            print(f"✅ Fixed {fixed_files} Info.plist files with conflicting WatchKit keys")
        else:
            print("✅ No additional conflicting WatchKit keys found in Info.plist files")
        
        print("✅ Operation completed successfully")
        return True
    except Exception as e:
        print(f"❌ Error during execution: {str(e)}")
        return False

if __name__ == "__main__":
    main()
