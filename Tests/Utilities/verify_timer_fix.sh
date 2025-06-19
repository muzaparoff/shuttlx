#!/bin/bash

# ShuttlX Timer Fix Verification Script
# Verifies the rewritten timer system builds and functions correctly

echo "🧪 ShuttlX Timer Rewrite Verification"
echo "====================================="

cd /Users/sergey/Documents/github/shuttlx

echo "📋 Step 1: Checking source files..."
if [ -f "ShuttlXWatch Watch App/WatchWorkoutManager.swift" ]; then
    echo "✅ WatchWorkoutManager.swift exists"
else
    echo "❌ WatchWorkoutManager.swift missing"
    exit 1
fi

echo "📋 Step 2: Checking for rewritten timer methods..."
if grep -q "startRewrittenTimerSystem" "ShuttlXWatch Watch App/WatchWorkoutManager.swift"; then
    echo "✅ Found rewritten timer system"
else
    echo "❌ Rewritten timer system not found"
    exit 1
fi

if grep -q "handleRewrittenTimerTick" "ShuttlXWatch Watch App/WatchWorkoutManager.swift"; then
    echo "✅ Found rewritten timer tick handler"
else
    echo "❌ Rewritten timer tick handler not found"
    exit 1
fi

echo "📋 Step 3: Building watchOS app..."
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlXWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build -quiet

if [ $? -eq 0 ]; then
    echo "✅ watchOS app builds successfully"
else
    echo "❌ watchOS app build failed"
    exit 1
fi

echo "📋 Step 4: Running timer tests..."
xcodebuild test -project ShuttlX.xcodeproj -scheme ShuttlX -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ShuttlXTests/WatchTimerRewriteTests -quiet

if [ $? -eq 0 ]; then
    echo "✅ Timer tests passed"
else
    echo "❌ Timer tests failed"
fi

echo ""
echo "🎉 Timer Rewrite Verification Complete!"
echo ""
echo "🚀 Next Steps:"
echo "1. Deploy to watchOS simulator"
echo "2. Navigate to any training program"
echo "3. Press 'Start Training'"
echo "4. Verify timer counts down from interval time (not 00:00)"
echo ""
echo "Expected behavior:"
echo "- Timer shows interval duration (e.g., '01:00' for 1-minute walk)"
echo "- Timer counts down: 01:00 → 00:59 → 00:58 → ..."
echo "- Timer transitions between intervals automatically"
echo ""
