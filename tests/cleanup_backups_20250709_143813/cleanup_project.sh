#!/bin/bash

# cleanup_project.sh
# Script to safely clean up unused scripts and backup files
# Author: GitHub Copilot
# Date: July 9, 2025

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Set up colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 ShuttlX Project Cleanup Script${NC}"
echo "========================================"

# Create backup directory for storing backups of files we remove
BACKUP_DIR="${SCRIPT_DIR}/cleanup_backups_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo -e "${YELLOW}📁 Created backup directory: ${BACKUP_DIR}${NC}"

# Essential scripts that should be kept
ESSENTIAL_SCRIPTS=(
    "build_and_test_both_platforms.sh"
    "build_for_physical_device.sh"
    "remove_infoplist_from_resources.py"
    "fix_watchkit_infoplist_keys.py"
    "auto_fix_files.py"
    "add_missing_swift_files.py"
    "test_phase19_final_integration.swift"
    "sync_fix_implementation.swift"
    "sync_fix_verification.swift"
    "debug_ui_freeze.swift"
)

# Create a function to safely move files to backup directory
safe_backup() {
    local file="$1"
    if [ -f "$file" ]; then
        echo -e "  ${YELLOW}🔄 Moving to backup: $(basename "$file")${NC}"
        cp "$file" "${BACKUP_DIR}/$(basename "$file")"
        rm "$file"
    fi
}

# Cleanup test scripts that are redundant or superseded
echo -e "${YELLOW}🔍 Cleaning up redundant scripts in tests directory...${NC}"
for script in "${SCRIPT_DIR}"/*.py "${SCRIPT_DIR}"/*.sh "${SCRIPT_DIR}"/*.swift; do
    if [ ! -f "$script" ]; then continue; fi
    
    filename=$(basename "$script")
    keep=false
    
    # Check if this is an essential script
    for essential in "${ESSENTIAL_SCRIPTS[@]}"; do
        if [ "$filename" == "$essential" ]; then
            keep=true
            break
        fi
    done
    
    if [ "$keep" == false ]; then
        safe_backup "$script"
    else
        echo -e "  ${GREEN}✓ Keeping essential script: $filename${NC}"
    fi
done

# Cleanup project.pbxproj backup files
echo -e "\n${YELLOW}🔍 Cleaning up project.pbxproj backup files...${NC}"
for backup in "${PROJECT_DIR}/ShuttlX.xcodeproj"/project.pbxproj.*; do
    if [ -f "$backup" ]; then
        safe_backup "$backup"
    fi
done

# Cleanup project.pbxproj backup files in tests directory
echo -e "\n${YELLOW}🔍 Cleaning up project.pbxproj backups in tests directory...${NC}"
for backup in "${SCRIPT_DIR}"/project.pbxproj.*; do
    if [ -f "$backup" ]; then
        safe_backup "$backup"
    fi
done

echo -e "\n${GREEN}✅ Cleanup completed!${NC}"
echo -e "${YELLOW}🔄 All removed files were backed up to: ${BACKUP_DIR}${NC}"
echo ""
echo -e "${BLUE}🧪 Running build verification test...${NC}"

# Run a build test to ensure nothing is broken
echo ""
read -p "Do you want to run a build test to verify everything still works? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Use the CD command to run from project root
    (cd "$PROJECT_DIR" && "${SCRIPT_DIR}/build_and_test_both_platforms.sh")
    BUILD_RESULT=$?
    
    if [ $BUILD_RESULT -eq 0 ]; then
        echo -e "\n${GREEN}✅ Build successful! Cleanup did not break the build process.${NC}"
    else
        echo -e "\n${RED}❌ Build failed! You might need to restore some files from the backup directory: ${BACKUP_DIR}${NC}"
    fi
else
    echo -e "${YELLOW}⏭️  Skipping build verification.${NC}"
    echo -e "${YELLOW}💡 Remember to run '${SCRIPT_DIR}/build_and_test_both_platforms.sh' later to verify everything works.${NC}"
fi
