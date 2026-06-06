---
name: ShuttlX App Store Screenshots
description: Location of App Store screenshots for ShuttlX on the local machine
type: reference
---

App Store screenshots are stored at `/Users/sergeymuzyukin/Desktop/ShuttlX-Screenshots/`.

Folder structure:
- `raw/` — original exports from Photos (iPhone native resolution)
- `raw2/` — additional raw exports
- `iPhone-6.9-inch/` — resized to 1320×2868px for App Store (iPhone 6.9" slot)
- `iPhone-6.3-inch/` — resized to 1206×2622px for App Store (iPhone 6.3" slot)
- `iPhone-17-Pro-Max/` — 1320×2868px (same as 6.9-inch slot)
- `iPhone-16-Pro/` — 1206×2622px
- `iPhone-16-Plus/` — additional size
- `Watch-46mm/`, `Watch-Series10-46mm/`, `Watch-Ultra-3/` — Watch screenshots

Screenshots are named `01-screen-name.jpeg` etc.
To re-upload to App Store Connect: commit to `fastlane/screenshots/en-US/` and push a version tag.
