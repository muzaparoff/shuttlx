#!/usr/bin/env python3
"""
Script to clean up Xcode project.pbxproj file by removing references to deleted files
"""

import re

# Files that were deleted and need to be removed from project
DELETED_FILES = [
    # Services
    'AudioCoachingManager.swift',
    'APIService.swift', 
    'FormAnalysisManager.swift',
    'WeatherManager.swift',
    'MLModelManager_iOS.swift',
    'GamificationManager.swift',
    'MessagingService.swift',
    'SocialService.swift',
    'CloudKitManager.swift',
    'AIFormAnalysisService.swift',
    'LocationManager.swift',
    'AccessibilityManager.swift',
    'RealTimeMessagingService.swift',
    # Models
    'SocialModels.swift',
    'MessagingModels.swift'
]

def clean_project_file():
    """Clean up the project.pbxproj file"""
    
    with open('ShuttlX.xcodeproj/project.pbxproj', 'r') as f:
        content = f.read()
    
    # Track UUIDs of files to delete
    file_uuids = {}
    
    # Find all file references and their UUIDs
    for filename in DELETED_FILES:
        # Match file reference patterns like: 
        # C155D30F /* AudioCoachingManager.swift */ = {isa = PBXFileReference; ...
        pattern = rf'([A-F0-9]+)\s*/\*\s*{re.escape(filename)}\s*\*/'
        matches = re.findall(pattern, content)
        for uuid in matches:
            file_uuids[uuid] = filename
            print(f"Found UUID {uuid} for {filename}")
    
    # Remove all lines containing these UUIDs
    lines = content.split('\n')
    cleaned_lines = []
    
    for line in lines:
        should_keep = True
        for uuid, filename in file_uuids.items():
            if uuid in line:
                print(f"Removing line with {uuid} ({filename}): {line.strip()}")
                should_keep = False
                break
        
        if should_keep:
            cleaned_lines.append(line)
    
    # Write cleaned content back
    cleaned_content = '\n'.join(cleaned_lines)
    
    with open('ShuttlX.xcodeproj/project.pbxproj', 'w') as f:
        f.write(cleaned_content)
    
    print(f"\nCleaned up project file. Removed references to {len(file_uuids)} deleted files.")

if __name__ == "__main__":
    clean_project_file()
