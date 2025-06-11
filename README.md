# ShuttlX - Run-Walk Interval Training App

**A beautiful iOS and watchOS app for run-walk interval training with HealthKit integration.**

[![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)](https://developer.apple.com/ios/)
[![watchOS](https://img.shields.io/badge/watchOS-11.5+-red.svg)](https://developer.apple.com/watchos/)
[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org/)
[![Status](https://img.shields.io/badge/Status-Fully%20Functional-brightgreen.svg)](#)
[![Build](https://img.shields.io/badge/Build-Passing-success.svg)](#)
[![Timer](https://img.shields.io/badge/Timer-Fixed-success.svg)](#)

---

## 📅 Project Status (June 11, 2025)

### ✅ **FULLY FUNCTIONAL MVP** 
- **Build Status**: ✅ All targets compile successfully
- **Timer System**: ✅ **COMPLETELY FIXED** - Real-time countdown timers working
- **Dual Platform**: ✅ iOS (planning) + watchOS (training) workflow optimized
- **HealthKit**: ✅ Workout tracking and heart rate monitoring
- **User Experience**: ✅ Streamlined 2-tab watchOS interface

### 🎯 **Latest MVP Updates (June 11, 2025)**
1. **UI Redesign** - watchOS: 3 tabs → 2 tabs (Timer/Metrics + Controls)
2. **Platform Focus** - iOS: Planning only, watchOS: Full training experience  
3. **Timer Enhancement** - Fixed interval progression at 00:00
4. **Code Cleanup** - Removed debug "Quick Timer Test" button
5. **Build Verification** - All platforms building and deploying successfully

### 📦 **Version Releases & Docker Integration**
- **Current Version**: v1.6.0 (MVP Focus Complete)
- **Release Tracking**: See `/versions/releases/` for detailed changelogs
- **Docker Support**: Container-ready for CI/CD with Xcode Cloud
- **Automated Testing**: Multi-platform build verification pipeline

---

## 🚀 Quick Start

### **One-Command Setup**
```bash
# Build and launch both iOS and watchOS apps
./build_and_test_both_platforms.sh
```

### **Testing the Timer Fix**
1. Launch the script above
2. Open Apple Watch Simulator
3. Find ShuttlX app → Select training program
4. Press "Quick Timer Test" (blue button) for 10-second test
5. Verify real-time countdown: 10:00 → 09:59 → 09:58...

---

## ✨ Features

### 🏃‍♂️ **Interval Training Focus**
- **Run-Walk Programs**: 6 preset programs (Beginner → Advanced)
- **Custom Intervals**: Configure run/walk durations
- **Smart Timer**: Circular progress with real-time countdown
- **Automatic Progression**: Seamless interval transitions
- **Phase Indicators**: Warm-up → Run → Walk → Cool-down

### ⌚ **watchOS Experience**  
- **Native Watch App**: Standalone workout tracking
- **Beautiful Timer**: Fixed circular countdown display
- **Real-time Updates**: Heart rate, calories, distance
- **Haptic Feedback**: Interval transition notifications
- **Quick Controls**: Pause/resume, skip intervals, end workout
- **Debug Test Mode**: Quick 10-second timer test for verification

### 📊 **Health Integration**
- **HealthKit Sync**: Automatic workout data saving
- **Heart Rate Zones**: Monitor intensity levels (Recovery → Maximum)
- **Workout Metrics**: Distance, calories, elapsed time
- **Progress Tracking**: Interval completion tracking
- **Privacy First**: All data stays on your device

### 🔧 **Development Tools**
- **Automated Building**: One-command deployment
- **Simulator Support**: iPhone 16 + Apple Watch Series 10
- **Debug Logging**: Comprehensive timer debugging
- **Quick Testing**: Built-in test functions for rapid iteration

---

## 🛠️ Development & Architecture

### Requirements
- Xcode 16.0+
- iOS 18.0+ / watchOS 11.5+
- Swift 5.5+

### **MVP Architecture** (Simplified for Focus)
```
Core Services (6):
├── HealthManager              # HealthKit integration
├── IntervalTimerService       # Run-walk timer logic
├── WatchConnectivityManager   # Apple Watch sync
├── SettingsService           # User preferences
├── NotificationService       # Workout reminders
└── HapticFeedbackManager     # Tactile feedback

Core Models:
├── IntervalModels.swift      # Run-walk intervals, workout configs
├── SettingsModels.swift      # Basic app settings
├── UserModels.swift          # Essential user data
└── HealthModels.swift        # HealthKit data structures

Core Views:
├── IntervalWorkoutView       # Main workout interface
├── WorkoutSelectionView      # Training program selection
├── StatsView                # Health tracking
└── ProfileView              # User management
```

### **Project Structure**
```
ShuttlX/
├── ShuttlX/                           # iOS app source
│   ├── Models/                        # Data structures
│   ├── Services/                      # Business logic
│   ├── ViewModels/                    # MVVM view models
│   └── Views/                         # SwiftUI interfaces
├── ShuttlXWatch Watch App/            # watchOS app source  
│   ├── ContentView.swift              # Main watch interface
│   ├── WatchWorkoutManager.swift      # Watch workout logic
│   └── WatchConnectivityManager.swift # iPhone sync
├── build_and_test_both_platforms.sh  # Main automation script
└── docs/                             # Documentation
```

### **Building & Testing**
```bash
# 🚀 Automated build (recommended)
./build_and_test_both_platforms.sh

# 🔧 Manual Xcode build
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX" build
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlXWatch Watch App" build

# 🧪 Timer testing (after launch)
# 1. Open Watch Simulator
# 2. Launch ShuttlX Watch app
# 3. Press "Quick Timer Test" (blue button)
# 4. Verify countdown: 10:00 → 09:59 → 09:58...
```

---

## 📱 Usage Guide

### **iOS App Workflow**
1. **Program Selection**: Choose from 6 preset training programs
   - Beginner 5K (1min run, 2min walk)
   - HIIT Blast (1.5min run, 1min walk)  
   - Endurance Challenge (3min run, 1min walk)
   - Speed Demon (30sec run, 30sec walk)
   - Recovery Run (2min run, 3min walk)
   - Marathon Prep (4min run, 1min walk)

2. **Customization**: Modify intervals, duration, heart rate zones
3. **Sync**: Automatically syncs with paired Apple Watch

### **watchOS App Experience**
1. **Launch**: Find ShuttlX on Apple Watch home screen
2. **Select**: Choose training program from beautiful interface
3. **Test Timer**: Use "Quick Timer Test" for 10-second verification
4. **Start Workout**: Press "Start Workout" for full program
5. **Monitor**: Watch real-time circular countdown timer
6. **Control**: Pause/resume, skip intervals, end workout

### **Timer Interface (Fixed)**
- **Circular Progress**: Shows remaining interval time
- **Activity Indicators**: Visual cues for run/walk phases
- **Haptic Feedback**: Gentle taps for interval transitions
- **Heart Rate Zones**: Color-coded intensity monitoring
- **Quick Actions**: Accessible control buttons

---

## 🔧 Recent Major Fixes & Updates

### **🎯 Timer System Overhaul (June 11, 2025)**
**ISSUE**: watchOS timer stuck at 00:00, no real-time updates
**SOLUTION**: Complete timer architecture rebuild
- ✅ Fixed `DispatchQueue.main.async` threading issues
- ✅ Added proper `RunLoop.main.add(timer, forMode: .common)` integration
- ✅ Implemented explicit `objectWillChange.send()` UI updates
- ✅ Added immediate timer value initialization
- ✅ Created debug test mode with 10-second intervals

### **🏗️ Build System Optimization (June 10, 2025)**
**ISSUE**: Complex deployment process, manual simulator management
**SOLUTION**: Automated build scripts with error handling
- ✅ One-command build and deployment
- ✅ Automatic simulator detection and pairing
- ✅ Watch app installation with bundle validation
- ✅ Comprehensive logging and debugging output

### **📱 MVP Transformation (June 9, 2025)**
**ISSUE**: Over-complex app with too many features
**SOLUTION**: Focused run-walk interval training MVP
- ✅ Simplified from 11+ services to 6 core services
- ✅ Removed social, AI, weather, analytics features  
- ✅ Focused on run-walk methodology
- ✅ Streamlined models and views

### **🧹 Code Cleanup (June 8, 2025)**
**ISSUE**: Multiple backup files, compilation errors
**SOLUTION**: Complete codebase organization
- ✅ Removed duplicate files (*_complex.swift, *_simple.swift)
- ✅ Fixed missing type definitions and enum conflicts
- ✅ Resolved duplicate struct declarations
- ✅ All targets compile without errors

---

## 🚀 Version History

### **Current: v1.5.0-timer-fix-complete** (June 11, 2025)
- ✅ **MAJOR**: Timer system completely fixed and functional
- ✅ Quick timer test mode for easy verification
- ✅ Real-time countdown with proper UI updates
- ✅ Improved debugging and error handling

### **v1.4.0-build-success-mvp** (June 9, 2025)
- ✅ MVP transformation successful
- ✅ Clean compilation for both platforms
- ✅ Simplified architecture implementation

### **v1.3.0-run-walk-mvp-complete** (June 9, 2025)
- ✅ Run-walk interval training focus
- ✅ Streamlined services and models
- ✅ Primary workout interface completed

### **v1.2.0-build-success** (June 8, 2025)
- ✅ Automated build system implementation
- ✅ Simulator management and deployment

### **v1.1.0-workspace-cleanup** (June 8, 2025)
- ✅ Project organization and cleanup
- ✅ Duplicate file removal
- ✅ Compilation error fixes

---

## 🎯 Current Focus & Next Steps

### **Immediate Priorities**
1. **User Testing**: Gather feedback on timer functionality
2. **Performance**: Optimize battery usage during workouts
3. **Polish**: Minor UI refinements and animations

### **Future Enhancements**
1. **Advanced Programs**: More sophisticated interval patterns
2. **Progress Tracking**: Workout history and improvements
3. **Custom Workouts**: User-created interval programs
4. **Apple Watch Complications**: Quick access widgets

---

## 💡 For Developers

### **Key Technical Decisions**
- **Timer Architecture**: Direct `DispatchQueue.main.async` for watchOS reliability
- **MVVM Pattern**: Clean separation of concerns
- **HealthKit Integration**: Comprehensive workout tracking
- **SwiftUI**: Modern declarative UI framework
- **Simplified Services**: MVP-focused architecture

### **Known Limitations**
- Requires iOS 18.0+ for latest HealthKit features
- watchOS simulator may have heart rate limitations
- Timer requires active foreground app state for accuracy

### **Contributing**
1. Test the timer functionality using "Quick Timer Test"
2. Report any issues with detailed reproduction steps
3. Focus on run-walk interval training improvements
4. Maintain MVP simplicity in any additions

---

## 📄 License

This project is licensed under the MIT License. See `LICENSE` file for details.

---

## 🔗 Contact & Support

For technical issues or questions about the timer functionality:
1. Use the "Quick Timer Test" to isolate timer-specific problems
2. Check console output for debug logs with `[TIMER-FIX]` tags
3. Verify both iOS and watchOS simulators are properly paired

**Project Status**: ✅ **Fully Functional MVP with Fixed Timer System**

## 🎯 Status

**✅ FULLY FUNCTIONAL** - Ready for production use

- ✅ Beautiful timer interface (no more debug screens)
- ✅ Clean build system with automated testing
- ✅ Proper HealthKit integration
- ✅ Multi-platform iOS + watchOS support
- ✅ Professional UI/UX design

For detailed status information, see [PROJECT_STATUS.md](PROJECT_STATUS.md)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test with `./build_and_test_both_platforms.sh`
4. Submit a pull request

**Note**: The app is currently fully functional. Focus contributions on new features rather than bug fixes.