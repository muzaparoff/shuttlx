#!/bin/bash

# Script to fix Xcode project file by adding missing Swift files
# This script will help fix the build issues by ensuring all Swift files are properly referenced

set -e

echo "Fixing Xcode project file..."

PROJECT_FILE="ShuttlX.xcodeproj/project.pbxproj"
BACKUP_FILE="ShuttlX.xcodeproj/project.pbxproj.backup2"

# Create another backup
cp "$PROJECT_FILE" "$BACKUP_FILE"

echo "Created backup: $BACKUP_FILE"

# List files that should be in the iOS target
IOS_FILES=(
    "ShuttlX/ShuttlXApp.swift"
    "ShuttlX/ContentView.swift"
    "ShuttlX/Models/TrainingInterval.swift"
    "ShuttlX/Models/TrainingProgram.swift"
    "ShuttlX/Models/TrainingSession.swift"
    "ShuttlX/Services/DataManager.swift"
    "ShuttlX/Services/WatchConnectivityManager.swift"
    "ShuttlX/Views/ProgramListView.swift"
    "ShuttlX/Views/ProgramEditorView.swift"
    "ShuttlX/Views/TrainingHistoryView.swift"
    "ShuttlX/Views/SessionRowView.swift"
    "ShuttlX/Views/ProgramRowView.swift"
)

# List files that should be in the watchOS target
WATCH_FILES=(
    "ShuttlXWatch Watch App/ShuttlXWatchApp.swift"
    "ShuttlXWatch Watch App/ContentView.swift"
    "ShuttlXWatch Watch App/Models/TrainingInterval.swift"
    "ShuttlXWatch Watch App/Models/TrainingProgram.swift"
    "ShuttlXWatch Watch App/Services/WatchWorkoutManager.swift"
    "ShuttlXWatch Watch App/Services/WatchConnectivityManager.swift"
    "ShuttlXWatch Watch App/Views/ProgramSelectionView.swift"
    "ShuttlXWatch Watch App/Views/TrainingView.swift"
)

echo "Files that should be in iOS target:"
for file in "${IOS_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file (exists)"
    else
        echo "  ✗ $file (missing)"
    fi
done

echo ""
echo "Files that should be in watchOS target:"
for file in "${WATCH_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file (exists)"
    else
        echo "  ✗ $file (missing)"
    fi
done

echo ""
echo "To fix the project, you need to:"
echo "1. Open ShuttlX.xcodeproj in Xcode"
echo "2. Delete references to old/missing Swift files"
echo "3. Add the files listed above to their respective targets"
echo ""
echo "Alternatively, let's try to open Xcode and add the files automatically..."
