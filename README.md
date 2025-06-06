# ShuttlX - Intelligent Shuttle Run & Interval Training

A comprehensive iOS and Apple Watch app for shuttle run and interval training with AI-powered coaching, adaptive training programs, and advanced analytics.

## Features

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
ShuttlX/
├── iOS App/
│   ├── Views/
│   ├── ViewModels/
│   ├── Models/
│   ├── Services/
│   └── Resources/
├── watchOS App/
│   ├── Views/
│   ├── ViewModels/
│   └── Complications/
├── Shared/
│   ├── Models/
│   ├── Services/
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
