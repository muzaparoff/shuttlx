#!/usr/bin/env python3

import re
import shutil
from datetime import datetime

def clean_project_file():
    """
    Clean up duplicate entries and misplaced files in the Xcode project file
    """
    project_file = "/Users/sergey/Documents/github/shuttlx/ShuttlX.xcodeproj/project.pbxproj"
    
    # Create backup
    backup_file = f"{project_file}.backup_cleanup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(project_file, backup_file)
    print(f"✅ Created backup: {backup_file}")
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Keep track of seen entries to remove duplicates
    seen_build_files = set()
    seen_file_refs = set()
    lines = content.split('\n')
    cleaned_lines = []
    
    # Problematic Swift files that shouldn't be in watchOS bundle resources
    problematic_files = [
        'ContentView.swift', 'TrainingInterval.swift', 'TrainingProgram.swift',
        'TrainingSession.swift', 'DataManager.swift', 'SharedDataManager.swift',
        'ShuttlXApp.swift', 'DebugView.swift', 'ProgramEditorView.swift',
        'ProgramListView.swift', 'ProgramRowView.swift', 'SessionRowView.swift',
        'TrainingHistoryView.swift'
    ]
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Check for duplicate build file entries
        build_file_match = re.search(r'([A-Z0-9]{8})\s+/\*\s+(.+?)\s+in\s+(Sources|Resources)\s+\*/', line)
        if build_file_match:
            file_id, filename, build_phase = build_file_match.groups()
            entry_key = f"{filename}_{build_phase}"
            
            # Skip if we've already seen this file in this build phase
            if entry_key in seen_build_files:
                print(f"🗑️  Removing duplicate build file entry: {filename} in {build_phase}")
                i += 1
                continue
            
            # Skip if this is a Swift file in the watchOS Resources phase  
            if build_phase == "Resources" and any(pf in filename for pf in problematic_files):
                print(f"🗑️  Removing misplaced Swift file from Resources: {filename}")
                i += 1
                continue
                
            seen_build_files.add(entry_key)
        
        # Check for duplicate file references
        file_ref_match = re.search(r'([A-Z0-9]{8})\s+/\*\s+(.+?)\s+\*/ = \{isa = PBXFileReference', line)
        if file_ref_match:
            file_id, filename = file_ref_match.groups()
            
            if filename in seen_file_refs:
                print(f"🗑️  Removing duplicate file reference: {filename}")
                i += 1
                continue
                
            seen_file_refs.add(filename)
        
        cleaned_lines.append(line)
        i += 1
    
    # Write the cleaned content
    cleaned_content = '\n'.join(cleaned_lines)
    
    with open(project_file, 'w') as f:
        f.write(cleaned_content)
    
    print(f"✅ Cleaned project file. Removed duplicate and misplaced entries.")
    print(f"📁 Original backed up to: {backup_file}")

if __name__ == "__main__":
    clean_project_file()
