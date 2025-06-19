#!/bin/bash

# Test script for manual verification function
cd /Users/sergey/Documents/github/shuttlx

# Source the main script to get access to functions
source ./build_and_test_both_platforms.sh

echo "🧪 Testing manual verification function..."
echo "1. Cleaning temporary files..."
rm -f /tmp/tests123_success /tmp/timer_verification_success /tmp/sync_verification_success /tmp/tests123_created 2>/dev/null || true

echo "2. Running manual verification..."
run_manual_comprehensive_verification

echo "3. Checking created success files..."
echo "Files that should exist:"
for file in /tmp/tests123_success /tmp/timer_verification_success /tmp/sync_verification_success /tmp/tests123_created; do
    if [ -f "$file" ]; then
        echo "  ✅ $file exists"
    else
        echo "  ❌ $file missing"
    fi
done

echo "4. Testing final status reporting..."
echo "   Tests123 workflow: $([ -f "/tmp/tests123_success" ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "   Timer verification: $([ -f "/tmp/timer_verification_success" ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "   Sync verification: $([ -f "/tmp/sync_verification_success" ] && echo "✅ PASSED" || echo "❌ FAILED")"

echo "🎉 Manual verification test complete!"
