# ShuttlX - Intelligent Shuttle Run & Interval Training

A comprehensive iOS and Apple Watch app for shuttle run and interval training with AI-powered coaching, custom training programs, and seamless dual-platform development workflow.

## 🎯 Project Status: v1.2.0 (June 9, 2025)

**✅ Dual-Platform Development Ready**
- ✅ iOS app builds and launches on iPhone 16 iOS 18.4
- ✅ watchOS app builds and installs on Apple Watch Series 10 watchOS 11.5
- ✅ Automated build and deployment scripts
- ✅ Complete development environment setup
- 🎯 **Next:** Custom training programs and watch app enhancements

## 🚀 Quick Start

### Development Environment Setup

The project includes automated scripts for seamless dual-platform development:

#### Main Automation Script
```bash
# Full automation workflow (recommended)
./build_and_test_both_platforms.sh full

# Build both platforms
./build_and_test_both_platforms.sh build-all

# Launch both apps
./build_and_test_both_platforms.sh launch-both

# Individual platform builds
./build_and_test_both_platforms.sh build-ios
./build_and_test_both_platforms.sh build-watchos

# Individual platform launches
./build_and_test_both_platforms.sh launch-ios
./build_and_test_both_platforms.sh launch-watchos

# Show available simulators
./build_and_test_both_platforms.sh show-sims

# Setup watch pairing
./build_and_test_both_platforms.sh setup-watch

# Run watchOS setup guide
./build_and_test_both_platforms.sh setup-watchos

# Show help
./build_and_test_both_platforms.sh help
```

#### watchOS Target Setup
If you need to set up the watchOS target from scratch:
```bash
./setup_watchos_target.sh
```

### Device Configuration
The automation scripts are configured for:
- **iOS**: iPhone 16 iOS 18.4
- **watchOS**: Apple Watch Series 10 (46mm) watchOS 11.5

## Features

### Current iOS App Features
- ✅ Complete onboarding flow with user profile setup
- ✅ Health permissions and HealthKit integration
- ✅ Physical information input (height, weight, fitness level)
- ✅ Fitness goals selection
- ✅ Modern SwiftUI interface with orange/red theme
- 🎯 **Coming Next**: Custom training program builder

### Current watchOS App Features
- ✅ Basic watchOS app structure
- ✅ Builds and installs successfully
- 🎯 **Coming Next**: Training program display and workout controls

### Planned Features
- 🎯 Custom training program builder (iOS)
- 🎯 Training program sync to Apple Watch
- 🎯 Workout execution on Apple Watch
- 🎯 Real-time heart rate monitoring
- 🎯 Progress tracking and analytics

### Core Functionality
- Intelligent shuttle run trainer with customizable distance intervals
- Adaptive training programs based on user performance
- Multiple training modes (Classic, HIIT, Tabata, Pyramid)
- Real-time audio coaching with motivational cues
- Smart rest period calculations based on heart rate recovery

### Apple Watch Integration
- Standalone Apple Watch app
- Custom complications for quick workout access
- Crown-based navigation during workouts
- Real-time heart rate zones with visual indicators

### HealthKit Integration
- Seamless sync with Apple Health
- Workout route tracking and elevation data
- Recovery metrics and readiness scores
- Export capabilities to other fitness platforms

### Advanced Features
- AI-powered form analysis using device sensors
- Progressive training plans with periodization
- Social features: challenges, leaderboards, team training
- Weather-aware workout suggestions
- Custom interval builder with visual timeline editor

## Technical Stack

- **UI Framework**: SwiftUI
- **Location Services**: Core Location
- **Health Integration**: HealthKit
- **Watch Connectivity**: WatchConnectivity
- **AI/ML**: Core ML
- **Cloud Storage**: CloudKit
- **Architecture**: MVVM with Combine

## Project Structure

```
ShuttlX/ (Root Project)
├── ShuttlX/ (iOS App - Main Xcode Project)
│   ├── ShuttlXApp.swift
│   ├── ContentView.swift
│   ├── ServiceLocator.swift
│   ├── Views/ (38 SwiftUI Views)
│   ├── ViewModels/ (18 ViewModels with Dependency Injection)
│   └── Services/ (Platform-specific iOS Services)
│       ├── AccessibilityManager.swift
│       ├── AudioCoachingManager.swift
│       ├── CloudKitManager.swift
│       ├── FormAnalysisManager.swift
│       ├── LocationManager.swift
│       ├── WeatherManager.swift
│       └── MLModelManager_iOS.swift
├── Shared/ (Cross-platform Code)
│   ├── Models/ (8 Data Models)
│   │   ├── UserModels.swift
│   │   ├── SocialModels.swift
│   │   ├── WorkoutModels.swift
│   │   ├── HealthModels.swift
│   │   ├── MessagingModels.swift
│   │   ├── NotificationModels.swift
│   │   ├── SettingsModels.swift
│   │   └── WorkoutTypes.swift
│   └── Services/ (12 Core Services)
│       ├── APIService.swift
│       ├── SocialService.swift
│       ├── HealthManager.swift
│       ├── NotificationService.swift
│       ├── MessagingService.swift
│       ├── GamificationManager.swift
│       ├── SettingsService.swift
│       ├── RealTimeMessagingService.swift
│       ├── AIFormAnalysisService.swift
│       ├── WatchConnectivityManager.swift
│       ├── HapticFeedbackManager.swift
│       └── MLModelManager.swift
├── WatchApp/ (Apple Watch App)
│   ├── ShuttlXWatchApp.swift
│   ├── WatchConnectivityManager.swift
│   ├── WatchWorkoutManager.swift
│   ├── Views/
│   ├── ViewModels/
│   └── Complications/
├── Tests/ (Unit Tests)
├── shuttlx_icon_set/ (App Icons)
└── versions/releases/ (Release Documentation)
```
│   └── Extensions/
└── Tests/
```

## Getting Started

1. Open the project in Xcode 15+
2. Configure your development team
3. Enable HealthKit capabilities
4. Build and run on iOS device or Apple Watch

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+
- Apple Developer Account (for HealthKit)

## License

See LICENSE file for details.
