# ShuttlX Dual Platform Development Guide

## 🎯 Project Status

✅ **COMPLETED:**
- iOS app project structure and code
- watchOS app code (complete implementation)
- Build scripts for multi-platform development
- Simulator setup and management
- WatchConnectivity implementation

⏳ **NEXT STEPS:**
- Add watchOS target to Xcode project
- Test iPhone-Watch app communication
- Verify HealthKit integration on both platforms

## 📁 Project Structure

```
/Users/sergey/Documents/github/shuttlx/
├── ShuttlX.xcodeproj/          # Main Xcode project (iOS only currently)
├── ShuttlX/                    # iOS app source code
│   ├── ShuttlXApp.swift       # iOS app entry point
│   ├── ContentView.swift      # Main iOS UI
│   ├── Models/                # Data models
│   ├── Views/                 # iOS UI components
│   ├── ViewModels/            # MVVM view models
│   └── Services/              # Business logic & managers
├── WatchApp/                   # watchOS app source code (ready to integrate)
│   ├── ShuttlXWatchApp.swift  # Watch app entry point
│   ├── WatchWorkoutManager.swift      # Watch workout management
│   ├── WatchConnectivityManager.swift # iPhone-Watch communication
│   └── Views/                 # Watch UI components
├── build_and_test_both_platforms.sh   # Multi-platform build script
├── setup_watchos_target.sh            # watchOS target setup guide
└── WATCH_SETUP_GUIDE.md              # Detailed setup instructions
```

## 🚀 Quick Start

### Step 1: Add watchOS Target to Xcode Project

```bash
./setup_watchos_target.sh
```

This script will:
1. Open your Xcode project
2. Guide you through adding a watchOS App target
3. Help you integrate the existing watchOS code
4. Configure target settings and permissions

### Step 2: Build and Test Both Platforms

```bash
# Build both platforms
./build_and_test_both_platforms.sh build-all

# Full setup: build, open simulators, and launch
./build_and_test_both_platforms.sh full

# Build iOS only
./build_and_test_both_platforms.sh build-ios

# Build watchOS only (after target is added)
./build_and_test_both_platforms.sh build-watchos
```

## 🛠 Available Commands

### Build Scripts

| Command | Description |
|---------|-------------|
| `./setup_watchos_target.sh` | Interactive guide to add watchOS target |
| `./build_and_test_both_platforms.sh` | Multi-platform build and test |

### Build Script Options

| Option | Description |
|--------|-------------|
| `build-ios` | Build iOS app only |
| `build-watchos` | Build watchOS app only |
| `build-all` | Build both iOS and watchOS apps |
| `launch-ios` | Install and launch iOS app in simulator |
| `setup-watch` | Setup iPhone-Watch simulator pairing |
| `open-sims` | Open both iOS and watchOS simulators |
| `show-sims` | Show available simulators |
| `full` | Complete build and setup process (default) |

## 📱 Simulator Setup

### Available Simulators
- **iOS:** iPhone 16 (currently configured)
- **watchOS:** Apple Watch Series 10 (46mm), Apple Watch Ultra 2, Apple Watch SE

### Pairing iPhone and Watch Simulators
The build script automatically attempts to pair the simulators for testing WatchConnectivity features.

## 🔗 WatchConnectivity Features

Both iOS and watchOS apps are implemented with WatchConnectivity for seamless communication:

### iOS (`WatchConnectivityManager.swift`)
- Sends workout data to watch
- Receives heart rate and workout updates from watch
- Handles app context and user info messages

### watchOS (`WatchConnectivityManager.swift`)
- Receives workout data from iPhone
- Sends heart rate data and workout progress
- Manages real-time communication during workouts

## 💪 Workout Features

### iOS App Features
- Workout selection and configuration
- Real-time stats and progress tracking
- Health data integration
- User profile and settings
- Notification management

### watchOS App Features
- Workout control and monitoring
- Heart rate tracking
- Progress visualization
- Quick workout actions
- Complications support

## 🏥 HealthKit Integration

Both platforms integrate with HealthKit for:
- Heart rate monitoring
- Workout tracking
- Calorie burn calculation
- Activity data synchronization

### Required Permissions
- Health data read/write access
- Workout monitoring
- Heart rate access

## 🐛 Troubleshooting

### Common Issues

1. **"No watchOS scheme found"**
   - Run `./setup_watchos_target.sh` to add watchOS target
   - Follow the guided setup process

2. **Build failures**
   - Check Xcode for detailed error messages
   - Verify all files are added to correct targets
   - Ensure HealthKit permissions are configured

3. **Simulator pairing issues**
   - Restart both simulators
   - Check Device pairing in Watch app on iOS simulator
   - Verify simulators are compatible versions

4. **WatchConnectivity not working**
   - Ensure both apps are running
   - Check that WCSession is activated on both sides
   - Verify apps are properly paired in simulators

### Getting Help

1. Check build output in Xcode for specific errors
2. Run `./build_and_test_both_platforms.sh show-sims` to verify simulator availability
3. Check the console output for connectivity debugging information

## 📋 Development Workflow

### Recommended Development Process

1. **Setup Phase:**
   ```bash
   ./setup_watchos_target.sh
   ```

2. **Development Phase:**
   ```bash
   # During development, build frequently
   ./build_and_test_both_platforms.sh build-all
   ```

3. **Testing Phase:**
   ```bash
   # Full testing setup
   ./build_and_test_both_platforms.sh full
   ```

4. **Debugging Phase:**
   - Use Xcode for detailed debugging
   - Monitor both iOS and watchOS console output
   - Test WatchConnectivity features with real data

## 🎯 Next Steps After Setup

1. **Complete watchOS Target Setup**
   - Follow the interactive setup guide
   - Verify both platforms build successfully

2. **Test WatchConnectivity**
   - Launch both apps in simulators
   - Send test data between iPhone and Watch
   - Verify real-time synchronization

3. **Validate HealthKit Integration**
   - Test health permissions on both platforms
   - Verify workout data is properly tracked
   - Check data synchronization with Health app

4. **Enhanced Testing**
   - Test different workout types
   - Verify background app refresh
   - Test notification delivery and interaction

## 🚀 Future Enhancements

- Automated UI testing for both platforms
- CI/CD pipeline for dual-platform builds
- Advanced workout analytics
- Social features and sharing
- Apple Fitness+ integration
- Customizable complications and widgets
