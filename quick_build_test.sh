#!/bin/bash

echo "🚀 Testing ShuttlX MVP Build Status"
echo "=================================="

cd /Users/sergey/Documents/github/shuttlx

echo "📁 Current directory: $(pwd)"
echo "📱 Available simulators:"
xcrun simctl list devices | grep "iPhone" | head -3

echo ""
echo "🔨 Starting build test..."

# Simple syntax check first
echo "📝 Checking Swift syntax..."
find ShuttlX -name "*.swift" -exec echo "Checking {}" \; -exec swift -frontend -parse {} \; 2>&1 | grep -E "(error|warning)" | head -10

echo ""
echo "🏗️ Attempting full build..."
xcodebuild -project ShuttlX.xcodeproj -scheme ShuttlX -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | tee build_output.log | tail -20

echo ""
echo "✅ Build test completed. Check build_output.log for details."
