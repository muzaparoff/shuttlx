#!/usr/bin/env python3
"""
Script to clean up Xcode project.pbxproj file by removing references to deleted files.
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

def clean_xcode_project(project_dir):
    """Clean up the Xcode project by removing references to deleted files"""
    
    project_path = os.path.join(project_dir, "ShuttlX.xcodeproj", "project.pbxproj")
    
    if not os.path.exists(project_path):
        print(f"❌ Project file not found: {project_path}")
        return False
    
    # Create backup
    backup_path = backup_project_file(project_path)
    
    # Files that were deleted and need to be removed from project
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
        # Other deleted files
        "SocialViewModel.swift",
        "ChallengeDetailViewModel.swift", 
        "InviteMembersViewModel.swift",
        "LeaderboardViewModel.swift",
        "TeamDetailViewModel.swift",
        "AchievementsViewModel.swift"
    ]
    
    # Read the project file
    with open(project_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = len(content.splitlines())
    
    # Remove references to deleted files
    for filename in deleted_files:
        # Remove various types of references to the file
        patterns = [
            rf'.*{re.escape(filename)}.*\n',  # Basic line containing filename
            rf'\s*[A-F0-9]+ /\* {re.escape(filename)} \*/.*\n',  # File reference comments
            rf'\s*[A-F0-9]+ = \{[^}]*{re.escape(filename)}[^}]*\};\n',  # File objects
        ]
        
        for pattern in patterns:
            content = re.sub(pattern, '', content, flags=re.MULTILINE)
    
    # Clean up empty lines and format
    lines = content.splitlines()
    cleaned_lines = []
    prev_line_empty = False
    
    for line in lines:
        line = line.rstrip()
        is_empty = len(line.strip()) == 0
        
        # Don't add multiple consecutive empty lines
        if is_empty and prev_line_empty:
            continue
            
        cleaned_lines.append(line)
        prev_line_empty = is_empty
    
    # Join lines back
    cleaned_content = '\n'.join(cleaned_lines) + '\n'
    
    # Write the cleaned content back
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(cleaned_content)
    
    cleaned_lines_count = len(cleaned_content.splitlines())
    removed_lines = original_lines - cleaned_lines_count
    
    print(f"✅ Cleaned project.pbxproj:")
    print(f"   - Original lines: {original_lines}")
    print(f"   - Cleaned lines: {cleaned_lines_count}")
    print(f"   - Removed lines: {removed_lines}")
    print(f"   - Processed {len(deleted_files)} deleted files")
    
    return True

if __name__ == "__main__":
    project_dir = "/Users/sergey/Documents/github/shuttlx"
    success = clean_xcode_project(project_dir)
    
    if success:
        print("\n🎉 Project cleanup completed successfully!")
        print("You can now try building the project again.")
    else:
        print("\n❌ Project cleanup failed!")
