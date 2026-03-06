# /screenshots — App Store Screenshot Capture

Capture simulator screenshots for App Store submission across all required device sizes.

## Required Device Sizes (App Store Connect)

### iPhone (Required)
| Device | Resolution | Simulator Name |
|--------|-----------|----------------|
| 6.9" (iPhone 17 Pro Max) | 1320 x 2868 | iPhone 17 Pro Max |
| 6.7" (iPhone 16 Plus) | 1290 x 2796 | iPhone 16 Plus |
| 6.5" (iPhone 15 Pro Max) | 1290 x 2796 | iPhone 15 Pro Max |
| 5.5" (iPhone 8 Plus) | 1242 x 2208 | iPhone 8 Plus |

### Apple Watch (Optional but recommended)
| Device | Resolution | Simulator |
|--------|-----------|-----------|
| Apple Watch Ultra 2 | 502 x 410 | Apple Watch Ultra 2 (49mm) |
| Apple Watch Series 10 | 416 x 496 | Apple Watch Series 10 (46mm) |

### iPad (If universal app)
| Device | Resolution |
|--------|-----------|
| 12.9" iPad Pro | 2048 x 2732 |
| 11" iPad Pro | 1668 x 2388 |

## Screens to Capture (in order)

### iPhone Screenshots (max 10)
1. **Dashboard** — main screen with workout stats
2. **Programs** — interval workout list with Free Run
3. **Active Workout** — timer screen mid-workout (mock data)
4. **Training Plans** — C25K / plan list
5. **Analytics** — fitness/fatigue chart, VO2max
6. **Session Detail** — post-workout with route map
7. **Themes** — side-by-side or settings showing 4 themes
8. **Live Activity** — Dynamic Island / Lock Screen
9. **Watch Sync** — showing connected Watch
10. **Widgets** — home screen with widgets

### Watch Screenshots (max 5)
1. **Home** — workout selection cards
2. **Active Workout** — timer + metrics
3. **Controls** — pause/stop circular buttons
4. **Complications** — watch face with complications

## Capture Commands

```bash
# Boot simulator
xcrun simctl boot "iPhone 17 Pro Max"

# Take screenshot
xcrun simctl io "iPhone 17 Pro Max" screenshot ~/Desktop/ShuttlX-Screenshots/iphone-6.9-dashboard.png

# For multiple devices, repeat with different simulator names

# Organize output
mkdir -p ~/Desktop/ShuttlX-Screenshots/{iPhone-6.9,iPhone-6.7,Watch-49mm}
```

## Usage

```
/screenshots              # Capture all screenshots for all devices
/screenshots iphone       # iPhone only
/screenshots watch        # Watch only
/screenshots dashboard    # Specific screen only
```

## Post-Processing Notes
- Screenshots need marketing frames (device bezels, text overlays, background)
- Use the image-generator MCP to create marketing compositions
- App Store allows 1-3 app preview videos (15-30 seconds)
- Recommended: add short headline text above each screenshot (e.g., "Track Every Interval")
