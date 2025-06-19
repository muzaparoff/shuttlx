#!/bin/bash

echo "🔍 REPOSITORY CLEANUP STATUS CHECK"
echo "=================================="

echo ""
echo "✅ MOVED FILES STATUS:"
echo "- ContentView_New.swift: $([ ! -f "ShuttlXWatch Watch App/ContentView_New.swift" ] && echo "✅ MOVED" || echo "❌ STILL PRESENT")"
echo "- ContentView_old.swift: $([ ! -f "ShuttlX/ContentView_old.swift" ] && echo "✅ MOVED" || echo "❌ STILL PRESENT")"

echo ""
echo "✅ MODELS STATUS:"
echo "- SharedModels.swift created: $([ -f "ShuttlXWatch Watch App/SharedModels.swift" ] && echo "✅ CREATED" || echo "❌ MISSING")"
echo "- TrainingModels.swift exists: $([ -f "ShuttlX/Models/TrainingModels.swift" ] && echo "✅ EXISTS" || echo "❌ MISSING")"

echo ""
echo "✅ TESTS ORGANIZATION:"
echo "- Tests folder exists: $([ -d "Tests" ] && echo "✅ EXISTS" || echo "❌ MISSING")"
echo "- Tests/UITests exists: $([ -d "Tests/UITests" ] && echo "✅ EXISTS" || echo "❌ MISSING")"
echo "- Tests/IntegrationTests exists: $([ -d "Tests/IntegrationTests" ] && echo "✅ EXISTS" || echo "❌ MISSING")"

echo ""
echo "✅ DOCUMENTATION STATUS:"
echo "- Documentation moved to versions/releases: $([ -d "versions/releases" ] && echo "✅ ORGANIZED" || echo "❌ MISSING")"

echo ""
echo "🚀 READY FOR AUTOMATION TESTING"
echo "Run: ./build_and_test_both_platforms.sh --full"
