#!/usr/bin/env python3
"""
Comprehensive Xcode project.pbxproj cleanup script
"""

import os
import re
import shutil
from datetime import datetime

def backup_project_file(project_path):
    """Create a backup of the project.pbxproj file"""
    backup_path = f"{project_path}.backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(project_path, backup_path)
    print(f"✅ Created backup: {backup_path}")
    return backup_path

def clean_xcode_project_comprehensive(project_dir):
    """Comprehensive cleanup of Xcode project references"""
    
    project_path = os.path.join(project_dir, "ShuttlX.xcodeproj", "project.pbxproj")
    
    if not os.path.exists(project_path):
        print(f"❌ Project file not found: {project_path}")
        return False
    
    # Create backup
    backup_path = backup_project_file(project_path)
    
    # Read the project file
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = len(content.splitlines())
    print(f"📄 Original project file: {original_lines} lines")
    
    # Files that were deleted and need complete removal
    deleted_files = [
        # Services
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
        # Models
        "SocialModels.swift",
        "MessagingModels.swift",
        # Views  
        "AdvancedSettingsView.swift",
        "AnalyticsView.swift",
        "DashboardView.swift",
        "HealthDashboardView.swift",
        "IntervalEditView.swift",
        "MainMenuView.swift",
        "RouteMapView.swift",
        "TrainingSessionView.swift",
        "WorkoutConfigurationView.swift",
        "WorkoutPreviewView.swift",
        "WorkoutSummaryView.swift",
        "WorkoutTimelineView.swift",
        "WorkoutView.swift",
        "WorkoutsView.swift",
        # ViewModels
        "CreateTrainingPlanViewModel.swift",
        "DashboardViewModel.swift",
        "TrainingPlansViewModel.swift",
        "TrainingSessionViewModel.swift",
        "WorkoutBuilderViewModel.swift",
        "WorkoutConfigurationViewModel.swift",
        "WorkoutTemplatesViewModel.swift",
        "WorkoutsViewModel.swift",
        "SocialViewModel.swift",
        "ChallengeDetailViewModel.swift", 
        "InviteMembersViewModel.swift",
        "LeaderboardViewModel.swift",
        "TeamDetailViewModel.swift",
        "AchievementsViewModel.swift"
    ]
    
    print(f"🗑️  Removing references to {len(deleted_files)} deleted files...")
    
    # Remove all types of references to deleted files
    for filename in deleted_files:
        removed_count = 0
        
        # Pattern 1: PBXBuildFile entries
        pattern1 = rf'^\s*[A-F0-9]+ /\* {re.escape(filename)} in Sources \*/ = \{{isa = PBXBuildFile; fileRef = [A-F0-9]+ /\* {re.escape(filename)} \*/; \}};\n'
        matches = re.findall(pattern1, content, re.MULTILINE)
        removed_count += len(matches)
        content = re.sub(pattern1, '', content, flags=re.MULTILINE)
        
        # Pattern 2: PBXFileReference entries
        pattern2 = rf'^\s*[A-F0-9]+ /\* {re.escape(filename)} \*/ = \{{isa = PBXFileReference; lastKnownFileType = [^;]+; path = {re.escape(filename)}; sourceTree = [^;]+; \}};\n'
        matches = re.findall(pattern2, content, re.MULTILINE)
        removed_count += len(matches)
        content = re.sub(pattern2, '', content, flags=re.MULTILINE)
        
        # Pattern 3: Build phase entries
        pattern3 = rf'^\s*[A-F0-9]+ /\* {re.escape(filename)} in Sources \*/,?\n'
        matches = re.findall(pattern3, content, re.MULTILINE)
        removed_count += len(matches)
        content = re.sub(pattern3, '', content, flags=re.MULTILINE)
        
        # Pattern 4: Generic file references
        pattern4 = rf'^.*{re.escape(filename)}.*\n'
        before_lines = len(content.splitlines())
        content = re.sub(pattern4, '', content, flags=re.MULTILINE)
        after_lines = len(content.splitlines())
        removed_count += (before_lines - after_lines)
        
        if removed_count > 0:
            print(f"   📝 {filename}: removed {removed_count} references")
    
    # Clean up orphaned commas and fix formatting
    content = re.sub(r',(\s*\n\s*\);)', r'\1', content)  # Remove trailing commas before closing parentheses
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)  # Remove multiple empty lines
    
    # Write the cleaned content back
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    cleaned_lines = len(content.splitlines())
    removed_lines = original_lines - cleaned_lines
    
    print(f"\n✅ Project cleanup completed:")
    print(f"   📊 Original lines: {original_lines}")
    print(f"   📊 Cleaned lines: {cleaned_lines}")
    print(f"   📊 Removed lines: {removed_lines}")
    
    return True

if __name__ == "__main__":
    project_dir = "/Users/sergey/Documents/github/shuttlx"
    success = clean_xcode_project_comprehensive(project_dir)
    
    if success:
        print("\n🎉 Comprehensive project cleanup completed!")
        print("✅ You can now try building the project in Xcode.")
    else:
        print("\n❌ Project cleanup failed!")
