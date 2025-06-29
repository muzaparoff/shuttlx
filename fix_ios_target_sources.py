#!/usr/bin/env python3
"""
Fix iOS Target Sources Build Phase
==================================
This script ensures all iOS Swift files are properly added to the iOS target's Sources build phase.
"""

import os
import re
import uuid
import json
from datetime import datetime

def create_uuid():
    """Generate a unique ID for Xcode project entries"""
    return uuid.uuid4().hex.upper()[:8]

def backup_project_file(project_path):
    """Create a backup of the project file"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = f"{project_path}.backup_ios_sources_{timestamp}"
    
    with open(project_path, 'r') as src, open(backup_path, 'w') as dst:
        dst.write(src.read())
    
    print(f"📦 Backup created: {os.path.basename(backup_path)}")
    return backup_path

def find_ios_swift_files():
    """Find all Swift files that should be in the iOS target"""
    ios_files = []
    shuttlx_dir = "ShuttlX"
    
    # Skip these files (they're either watchOS specific or test files)
    skip_files = {
        'ShuttlXWatchApp.swift',
        'WatchWorkoutManager.swift', 
        'WatchWorkoutManager_clean.swift',
        'ProgramSelectionView.swift',
        'TrainingView.swift'
    }
    
    if os.path.exists(shuttlx_dir):
        for root, dirs, files in os.walk(shuttlx_dir):
            # Skip hidden directories and build directories
            dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'build']
            
            for file in files:
                if file.endswith('.swift') and file not in skip_files:
                    full_path = os.path.join(root, file)
                    ios_files.append(full_path)
    
    return sorted(ios_files)

def read_project_file(project_path):
    """Read the Xcode project file"""
    with open(project_path, 'r', encoding='utf-8') as f:
        return f.read()

def find_ios_target_id(content):
    """Find the iOS target ID"""
    # Look for the ShuttlX target (not the watch target)
    # Find all PBXNativeTarget entries first
    target_pattern = r'([A-F0-9]+)\s*/\*\s*([^*]+)\s*\*/\s*=\s*\{\s*isa\s*=\s*PBXNativeTarget;'
    matches = re.finditer(target_pattern, content, re.DOTALL)
    
    for match in matches:
        target_id = match.group(1)
        target_name = match.group(2).strip()
        # Look for the exact ShuttlX target (not the watch app)
        if target_name == "ShuttlX":
            return target_id
    
    return None

def find_sources_build_phase_id(content, target_id):
    """Find the Sources build phase ID for the given target"""
    # Find the target definition
    target_pattern = f'{target_id}.*?buildPhases\\s*=\\s*\\((.*?)\\);'
    target_match = re.search(target_pattern, content, re.DOTALL)
    
    if not target_match:
        return None
    
    build_phases = target_match.group(1)
    
    # Find all build phase IDs in the target (look for complete IDs)
    phase_ids = re.findall(r'([A-F0-9]{8,})', build_phases)
    
    # Check each phase to see if it's a Sources build phase
    for phase_id in phase_ids:
        # Look for the build phase definition
        phase_pattern = f'{phase_id}\\s*/\\*\\s*Sources\\s*\\*/\\s*=\\s*{{\\s*isa\\s*=\\s*PBXSourcesBuildPhase'
        if re.search(phase_pattern, content):
            return phase_id
    
    return None

def get_existing_file_references(content):
    """Get all existing file references and their paths"""
    file_refs = {}
    
    # Find all PBXFileReference entries
    pattern = r'([A-F0-9]{24})\s*/\*.*?\*/\s*=\s*\{[^}]*isa\s*=\s*PBXFileReference;[^}]*path\s*=\s*([^;]+);[^}]*\}'
    matches = re.finditer(pattern, content, re.DOTALL)
    
    for match in matches:
        ref_id = match.group(1)
        path = match.group(2).strip().strip('"')
        file_refs[path] = ref_id
    
    return file_refs

def get_existing_build_files(content):
    """Get all existing build file references"""
    build_files = {}
    
    # Find all PBXBuildFile entries
    pattern = r'([A-F0-9]{24})\s*/\*.*?\*/\s*=\s*\{[^}]*isa\s*=\s*PBXBuildFile;[^}]*fileRef\s*=\s*([A-F0-9]{24})'
    matches = re.finditer(pattern, content)
    
    for match in matches:
        build_file_id = match.group(1)
        file_ref_id = match.group(2)
        build_files[file_ref_id] = build_file_id
    
    return build_files

def get_files_in_sources_phase(content, sources_phase_id):
    """Get all files currently in the Sources build phase"""
    if not sources_phase_id:
        return set()
    
    # Find the Sources build phase
    phase_pattern = f'{sources_phase_id}.*?files\\s*=\\s*\\((.*?)\\);'
    phase_match = re.search(phase_pattern, content, re.DOTALL)
    
    if not phase_match:
        return set()
    
    files_section = phase_match.group(1)
    
    # Extract all build file IDs
    build_file_ids = re.findall(r'([A-F0-9]{24})', files_section)
    
    return set(build_file_ids)

def add_missing_files_to_sources_phase(content, sources_phase_id, missing_build_file_ids):
    """Add missing build files to the Sources build phase"""
    if not sources_phase_id or not missing_build_file_ids:
        return content
    
    # Find the Sources build phase files section
    phase_pattern = f'({sources_phase_id}.*?files\\s*=\\s*\\()(.*?)(\\);)'
    phase_match = re.search(phase_pattern, content, re.DOTALL)
    
    if not phase_match:
        print(f"⚠️  Could not find Sources build phase files section")
        return content
    
    before = phase_match.group(1)
    files_section = phase_match.group(2)
    after = phase_match.group(3)
    
    # Add missing files to the files section
    new_files = []
    for build_file_id in missing_build_file_ids:
        new_files.append(f"\t\t\t\t{build_file_id} /* in Sources */,")
    
    # Insert new files before the closing
    if files_section.strip():
        # There are existing files, add after them
        new_files_section = files_section.rstrip().rstrip(',') + ',\n' + '\n'.join(new_files)
    else:
        # No existing files, just add ours
        new_files_section = '\n' + '\n'.join(new_files) + '\n\t\t\t'
    
    new_content = content.replace(
        before + files_section + after,
        before + new_files_section + after
    )
    
    print(f"✅ Added {len(missing_build_file_ids)} files to Sources build phase")
    return new_content

def add_missing_file_references(content, missing_files, existing_file_refs):
    """Add missing PBXFileReference entries"""
    new_refs = {}
    new_entries = []
    
    # Find the PBXFileReference section
    file_ref_section_pattern = r'(/\* Begin PBXFileReference section \*/.*?)(/\* End PBXFileReference section \*/)'
    file_ref_match = re.search(file_ref_section_pattern, content, re.DOTALL)
    
    if not file_ref_match:
        print("⚠️  Could not find PBXFileReference section")
        return content, new_refs
    
    for file_path in missing_files:
        if file_path not in existing_file_refs:
            file_ref_id = create_uuid()
            filename = os.path.basename(file_path)
            
            # Create the file reference entry
            entry = f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};"
            new_entries.append(entry)
            new_refs[file_path] = file_ref_id
            
            print(f"  📄 Adding file reference: {file_path} -> {file_ref_id}")
    
    if new_entries:
        # Insert new file references before the end of the section
        before = file_ref_match.group(1)
        after = file_ref_match.group(2)
        
        new_section = before.rstrip() + '\n' + '\n'.join(new_entries) + '\n\t' + after
        content = content.replace(file_ref_match.group(0), new_section)
    
    return content, new_refs

def add_missing_build_files(content, missing_files, file_refs, existing_build_files):
    """Add missing PBXBuildFile entries"""
    new_build_files = {}
    new_entries = []
    
    # Find the PBXBuildFile section
    build_file_section_pattern = r'(/\* Begin PBXBuildFile section \*/.*?)(/\* End PBXBuildFile section \*/)'
    build_file_match = re.search(build_file_section_pattern, content, re.DOTALL)
    
    if not build_file_match:
        print("⚠️  Could not find PBXBuildFile section")
        return content, new_build_files
    
    for file_path in missing_files:
        file_ref_id = file_refs.get(file_path)
        if file_ref_id and file_ref_id not in existing_build_files:
            build_file_id = create_uuid()
            filename = os.path.basename(file_path)
            
            # Create the build file entry
            entry = f"\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};"
            new_entries.append(entry)
            new_build_files[file_ref_id] = build_file_id
            
            print(f"  🔧 Adding build file: {filename} -> {build_file_id}")
    
    if new_entries:
        # Insert new build files before the end of the section
        before = build_file_match.group(1)
        after = build_file_match.group(2)
        
        new_section = before.rstrip() + '\n' + '\n'.join(new_entries) + '\n\t' + after
        content = content.replace(build_file_match.group(0), new_section)
    
    return content, new_build_files

def main():
    project_path = "ShuttlX.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_path):
        print("❌ project.pbxproj not found!")
        return False
    
    print("🔧 Fixing iOS Target Sources Build Phase")
    print("=" * 50)
    
    # Find iOS Swift files
    ios_files = find_ios_swift_files()
    print(f"📋 Found {len(ios_files)} iOS Swift files")
    
    # Create backup
    backup_project_file(project_path)
    
    # Read project file
    content = read_project_file(project_path)
    
    # Find iOS target
    ios_target_id = find_ios_target_id(content)
    if not ios_target_id:
        print("❌ Could not find iOS target")
        return False
    
    print(f"🎯 iOS target ID: {ios_target_id}")
    
    # Find Sources build phase
    sources_phase_id = find_sources_build_phase_id(content, ios_target_id)
    if not sources_phase_id:
        print("❌ Could not find Sources build phase")
        return False
    
    print(f"📦 Sources build phase ID: {sources_phase_id}")
    
    # Get existing references
    existing_file_refs = get_existing_file_references(content)
    existing_build_files = get_existing_build_files(content)
    files_in_sources = get_files_in_sources_phase(content, sources_phase_id)
    
    print(f"📄 Existing file references: {len(existing_file_refs)}")
    print(f"🔧 Existing build files: {len(existing_build_files)}")
    print(f"📦 Files in Sources phase: {len(files_in_sources)}")
    
    # Find missing files
    missing_files = []
    all_file_refs = {}
    
    for file_path in ios_files:
        filename = os.path.basename(file_path)
        
        # Check if file reference exists (by filename)
        file_ref_id = None
        for path, ref_id in existing_file_refs.items():
            if os.path.basename(path) == filename:
                file_ref_id = ref_id
                break
        
        if file_ref_id:
            all_file_refs[file_path] = file_ref_id
            
            # Check if build file exists
            build_file_id = existing_build_files.get(file_ref_id)
            if build_file_id:
                # Check if it's in Sources build phase
                if build_file_id not in files_in_sources:
                    missing_files.append(file_path)
                    print(f"  ⚠️  {filename} exists but not in Sources phase")
            else:
                missing_files.append(file_path)
                print(f"  ⚠️  {filename} has file reference but no build file")
        else:
            missing_files.append(file_path)
            print(f"  ❌ {filename} completely missing")
    
    if not missing_files:
        print("✅ All iOS Swift files are already properly configured")
        return True
    
    print(f"\n🔧 Processing {len(missing_files)} missing files...")
    
    # Add missing file references
    content, new_file_refs = add_missing_file_references(content, missing_files, existing_file_refs)
    all_file_refs.update(new_file_refs)
    
    # Add missing build files
    content, new_build_files = add_missing_build_files(content, missing_files, all_file_refs, existing_build_files)
    
    # Collect all build file IDs that need to be added to Sources phase
    missing_build_file_ids = []
    for file_path in missing_files:
        file_ref_id = all_file_refs.get(file_path)
        if file_ref_id:
            build_file_id = existing_build_files.get(file_ref_id) or new_build_files.get(file_ref_id)
            if build_file_id:
                missing_build_file_ids.append(build_file_id)
    
    # Add missing files to Sources build phase
    content = add_missing_files_to_sources_phase(content, sources_phase_id, missing_build_file_ids)
    
    # Write updated project file
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\n✅ Successfully updated iOS target Sources build phase")
    print(f"📄 Added {len(missing_build_file_ids)} files to Sources build phase")
    
    return True

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
