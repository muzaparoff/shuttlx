# ShuttlX Run-Walk Interval Training MVP

## 🎯 Core MVP Goal
**Run-Walk Interval Training App** for iOS and watchOS with simple, focused functionality.

## 📱 MVP Features (iOS + watchOS)

### Core Interval Training
- **Run-Walk Intervals**: Configurable run/walk durations
- **Visual Timer**: Large, clear countdown display
- **Audio Cues**: Voice prompts for interval changes
- **Haptic Feedback**: Vibration alerts for interval transitions
- **Basic Stats**: Time, distance, calories during workout

### Simple Configuration
- **Preset Intervals**: Beginner (1min run/2min walk), Intermediate (2min/1min), Advanced (3min/30sec)
- **Custom Intervals**: User-defined run/walk durations
- **Total Workout Time**: Set overall session length

### Essential Tracking
- **HealthKit Integration**: Store workouts to Apple Health
- **Basic Metrics**: Steps, distance, heart rate, calories
- **Workout History**: Simple list of completed sessions

## 🏗️ Simplified Architecture

### Core Services (3 only)
1. **IntervalTimerService**: Handle run-walk timing logic
2. **HealthKitService**: Basic health data and workout storage
3. **WatchConnectivityService**: Sync between iOS and watchOS

### Core Models (2 only)
1. **IntervalWorkout**: Run duration, walk duration, total time, current state
2. **WorkoutSession**: Date, duration, calories, distance, intervals completed

### Core Views
**iOS App:**
- `IntervalSetupView`: Configure run/walk intervals
- `WorkoutView`: Active workout with timer and controls
- `HistoryView`: Simple workout history list

**watchOS App:**
- `WatchWorkoutView`: Large timer display with start/stop
- `WatchStatsView`: Current workout metrics

## 🧹 Cleanup Strategy

### Remove All Non-MVP Files
- All `*_backup.swift` files
- All `Simple*.swift` duplicates  
- All social, analytics, coaching features
- Complex models and unused services

### Keep Only Essential Models
- Remove: `SocialModels`, `MessagingModels`, complex user preferences
- Keep: Basic `IntervalWorkout` and `WorkoutSession` models

### Simplify Service Layer
- Replace complex services with 3 focused services
- Remove: `AudioCoachingManager`, `APIService`, `FormAnalysisManager`, etc.
- Keep: Essential health and timer functionality only

## 📋 Implementation Plan

### Phase 1: Cleanup (Current)
1. Remove all backup and duplicate files
2. Fix compilation errors by removing complex dependencies
3. Create documentation structure with semantic versioning

### Phase 2: Core Services
1. Create `IntervalTimerService` with run-walk logic
2. Simplify `HealthKitService` to essential metrics only
3. Basic `WatchConnectivityService` for iOS-watchOS sync

### Phase 3: MVP Views
1. `IntervalSetupView`: Simple interval configuration
2. `WorkoutView`: Timer display with start/stop/pause
3. Basic history and stats views

### Phase 4: watchOS Integration
1. Large timer display on Apple Watch
2. Haptic feedback for interval changes
3. Basic workout controls (start/stop/pause)

## 🏷️ Documentation & Versioning Rules

### File Naming Convention
- `docs/CHANGELOG.md`: Version history with semantic versioning
- `docs/FEATURES.md`: Current feature list
- `docs/ARCHITECTURE.md`: Technical overview
- Only ONE release doc per version

### Commit Message Format
- `version: X.Y.Z - Description` (for releases)
- `add: Feature description` (new features)
- `fix: Bug description` (bug fixes)
- `clean: Cleanup description` (code cleanup)

### Version Strategy
- `1.0.0`: MVP with run-walk intervals
- `1.1.0`: Enhanced UI/UX improvements
- `1.2.0`: Advanced interval patterns
- `2.0.0`: Major feature additions

## 🎯 Success Criteria
- ✅ App builds without errors
- ✅ Basic run-walk intervals work on iOS
- ✅ Timer syncs between iOS and watchOS
- ✅ Workouts save to Apple Health
- ✅ Simple, clean codebase (<20 files total)
- ✅ Ready for App Store submission

**Focus: Simple, reliable run-walk interval training that just works.**
