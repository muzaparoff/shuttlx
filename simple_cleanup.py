#!/usr/bin/env python3

import re

def clean_pbxproj():
    file_path = "/Users/sergey/Documents/github/shuttlx/ShuttlX.xcodeproj/project.pbxproj"
    
    # Read the file
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Files to remove completely
    files_to_remove = [
        "AudioCoachingManager.swift",
        "APIService.swift", 
        "FormAnalysisManager.swift",
        "WeatherManager.swift",
        "MLModelManager_iOS.swift",
        "GamificationManager.swift",
        "MessagingService.swift",
        "SocialService.swift",
        "CloudKitManager.swift",
        "AIFormAnalysisService.swift",
        "LocationManager.swift",
        "AccessibilityManager.swift",
        "RealTimeMessagingService.swift",
        "SocialModels.swift",
        "MessagingModels.swift"
    ]
    
    print("Removing references...")
    
    # Remove each file's references
    for filename in files_to_remove:
        # Remove any line containing the filename
        lines = content.split('\n')
        filtered_lines = []
        removed_count = 0
        
        for line in lines:
            if filename in line:
                print(f"Removing: {line.strip()}")
                removed_count += 1
            else:
                filtered_lines.append(line)
        
        content = '\n'.join(filtered_lines)
        print(f"Removed {removed_count} lines for {filename}")
    
    # Write back
    with open(file_path, 'w') as f:
        f.write(content)
    
    print("✅ Cleanup complete!")

if __name__ == "__main__":
    clean_pbxproj()
