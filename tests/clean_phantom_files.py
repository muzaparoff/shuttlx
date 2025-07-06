#!/usr/bin/env python3
"""
Clean up phantom file references from Xcode project file.
This script removes references to Swift files that don't exist in the file system.
"""

import os
import re
import shutil
from datetime import datetime

def backup_project_file():
    """Create a backup of the project file."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = f"ShuttlX.xcodeproj/project.pbxproj.backup_cleanup_{timestamp}"
    shutil.copy("ShuttlX.xcodeproj/project.pbxproj", backup_path)
    print(f"📦 Backup created: {backup_path}")
    return backup_path

def get_missing_files():
    """Return list of files referenced in project but not in filesystem."""
    return [
        'ProfileViewModel.swift', 'OnboardingViewModel.swift', 'AppViewModel.swift', 'WorkoutViewModel.swift',
        'ViewPerformanceModifiers.swift', 'TrainingProgramDetailView.swift', 'ProgramsView.swift', 
        'NotificationsView.swift', 'SettingsView.swift', 'OnboardingView.swift', 'WorkoutSelectionView.swift',
        'ProfileView.swift', 'StatsView.swift', 'WorkoutDashboardView.swift', 'WorkoutModels.swift',
        'NotificationModels.swift', 'HealthModels.swift', 'WorkoutTypes.swift', 'UserModels.swift',
        'SettingsModels.swift', 'AdvancedPerformanceMonitor.swift', 'PerformanceOptimizationService.swift',
        'TrainingProgramSync.swift', 'CalorieCalculationService.swift', 'UserProfileService.swift',
        'SettingsService.swift', 'WatchConnectivityManager.swift', 'HapticFeedbackManager.swift',
        'HealthManager.swift', 'NotificationService.swift'
    ]

def clean_phantom_references():
    """Remove phantom file references from project file."""
    print("🔧 ShuttlX Phantom File Cleaner")
    print("=" * 40)
    
    # Create backup
    backup_path = backup_project_file()
    
    # Read project file
    with open("ShuttlX.xcodeproj/project.pbxproj", "r") as f:
        content = f.read()
    
    original_content = content
    missing_files = get_missing_files()
    removed_ids = set()
    
    print(f"🔍 Checking {len(missing_files)} phantom files...")
    
    for filename in missing_files:
        if filename in content:
            print(f"  ❌ Found phantom: {filename}")
            
            # Find PBXFileReference entries
            file_ref_pattern = rf'(\s+([A-F0-9]+) /\* {re.escape(filename)} \*/ = {{[^}}]+}};)'
            file_ref_matches = re.findall(file_ref_pattern, content)
            
            for match, file_id in file_ref_matches:
                content = content.replace(match, "")
                removed_ids.add(file_id)
                print(f"    🗑️  Removed PBXFileReference: {file_id}")
            
            # Find PBXBuildFile entries that reference the removed file IDs
            for file_id in removed_ids:
                build_file_pattern = rf'(\s+([A-F0-9]+) /\* {re.escape(filename)} in Sources \*/ = {{[^}}]+}};)'
                build_file_matches = re.findall(build_file_pattern, content)
                
                for match, build_id in build_file_matches:
                    content = content.replace(match, "")
                    print(f"    🗑️  Removed PBXBuildFile: {build_id}")
                    
                    # Remove build file reference from Sources build phase
                    sources_ref_pattern = rf'(\s+{re.escape(build_id)} /\* {re.escape(filename)} in Sources \*/,?\s*)'
                    content = re.sub(sources_ref_pattern, "", content)
                    print(f"    🗑️  Removed from Sources phase: {build_id}")
        else:
            print(f"  ✅ Not found: {filename}")
    
    # Clean up any remaining orphaned references
    print("\n🧹 Cleaning up orphaned references...")
    
    # Remove empty lines and fix formatting
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)  # Remove multiple empty lines
    content = re.sub(r',\s*\n\s*\)', '\n\t\t)', content)  # Fix trailing commas
    
    if content != original_content:
        # Write cleaned content
        with open("ShuttlX.xcodeproj/project.pbxproj", "w") as f:
            f.write(content)
        
        print(f"✅ Project file cleaned successfully!")
        print(f"📁 Original backed up to: {backup_path}")
        
        # Count changes
        removed_lines = len(original_content.split('\n')) - len(content.split('\n'))
        print(f"📊 Removed {len(removed_ids)} file references, {removed_lines} lines cleaned")
    else:
        print("ℹ️  No changes needed")
    
    return len(removed_ids) > 0

if __name__ == "__main__":
    clean_phantom_references()
