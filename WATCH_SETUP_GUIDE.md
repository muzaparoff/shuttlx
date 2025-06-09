# Adding watchOS Target to ShuttlX Project

## Manual Steps (in Xcode):

1. **Open Xcode Project**
   ```bash
   open ShuttlX.xcodeproj
   ```

2. **Add watchOS Target**
   - Select your project in the navigator
   - Click the "+" button in the Targets section
   - Choose "watchOS" → "App"
   - Product Name: "ShuttlX Watch App"
   - Bundle Identifier: com.shuttlx.ShuttlX.watchkitapp
   - Language: Swift
   - Use SwiftUI: ✅

3. **Configure Watch App Settings**
   - Watch App Bundle Identifier: `com.shuttlx.ShuttlX.watchkitapp`
   - WatchKit Extension Bundle Identifier: `com.shuttlx.ShuttlX.watchkitapp.watchkitextension`

## Alternative: Script-based Setup

If you prefer automated setup, run:

```bash
./setup_watch_target.sh
```

## What Gets Created:

- **ShuttlX Watch App** target
- **ShuttlX Watch App Extension** target
- Shared code between iOS and watchOS
- WatchConnectivity integration
- HealthKit permissions for Watch

## File Structure After Setup:

```
ShuttlX.xcodeproj/
├── ShuttlX (iOS Target)
├── ShuttlX Watch App (watchOS Target)
└── ShuttlX Watch App Extension

ShuttlX/
├── Shared/           # Code shared between iOS and watchOS
├── iOS/              # iOS-specific code
└── Watch/            # watchOS-specific code
```

## Testing Both Platforms:

1. **Build iOS App**: `cmd+B` or use build script
2. **Run on iPhone Simulator**: Select iPhone simulator and run
3. **Run on paired Apple Watch**: Select Apple Watch simulator and run
4. **Test WatchConnectivity**: Send data between devices

## Key Benefits:

- ✅ Shared business logic and models
- ✅ Real-time data sync via WatchConnectivity
- ✅ Independent testing of each platform
- ✅ Unified HealthKit integration
- ✅ Watch complications and notifications
