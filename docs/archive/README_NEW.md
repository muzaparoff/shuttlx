# ShuttlX - Run-Walk Interval Training App

**A beautiful iOS and watchOS app for run-walk interval training with HealthKit integration.**

[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![watchOS](https://img.shields.io/badge/watchOS-8.0+-red.svg)](https://developer.apple.com/watchos/)
[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org/)
[![Status](https://img.shields.io/badge/Status-Fully%20Functional-brightgreen.svg)](#)

---

## 🚀 Quick Start

### One-Command Setup
```bash
# Build and launch both iOS and watchOS apps
./build_and_test_both_platforms.sh
```

### Quick Testing
```bash
# Launch for manual testing
./launch_for_testing.sh
```

---

## ✨ Features

### 🏃‍♂️ Interval Training
- **Run-Walk Programs**: Beginner, Intermediate, Advanced presets
- **Custom Intervals**: Configure your own run/walk durations
- **Beautiful Timer**: Circular progress with activity indicators
- **Smart Controls**: Pause/resume, skip intervals, end workout

### ⌚ watchOS Experience  
- **Native Watch App**: Standalone workout tracking
- **Real-time Updates**: Heart rate, calories, distance
- **Haptic Feedback**: Interval transition notifications
- **Quick Actions**: Control workout from your wrist

### 📊 Health Integration
- **HealthKit Sync**: Automatic workout data saving
- **Heart Rate Zones**: Monitor intensity levels
- **Progress Tracking**: Workout history and statistics
- **Privacy First**: Data stays on your device

---

## 🛠️ Development

### Requirements
- Xcode 15.0+
- iOS 15.0+ / watchOS 8.0+
- Swift 5.5+

### Project Structure
```
ShuttlX/
├── ShuttlX/                    # iOS app source
├── ShuttlXWatch Watch App/     # watchOS app source  
├── build_and_test_both_platforms.sh  # Main automation
├── launch_for_testing.sh       # Quick launch
└── PROJECT_STATUS.md           # Detailed status
```

### Building
```bash
# Automated build (recommended)
./build_and_test_both_platforms.sh

# Manual Xcode build
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlX" build
xcodebuild -project ShuttlX.xcodeproj -scheme "ShuttlXWatch Watch App" build
```

---

## 📱 Usage

### iOS App
1. **Setup**: Choose a training program or create custom intervals
2. **Configure**: Set run/walk durations and total workout time  
3. **Start**: Launch workout and sync with Apple Watch

### watchOS App
1. **Select Program**: Choose from Beginner, Intermediate, Advanced
2. **Start Workout**: Press the big "Start Workout" button
3. **Follow Timer**: Beautiful circular timer shows remaining time
4. **Control**: Use pause/resume, skip, or end workout buttons

---

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
