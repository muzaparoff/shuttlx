# ShuttlX App Store marketing screenshots

- `raw/` — clean simulator captures: iPhone 17 Pro Max (1320x2868) timer heroes
  via the DEBUG snapshot harness (`SIMCTL_CHILD_SHUTTLX_SNAPSHOT=<themeID>`),
  plus Apple Watch Series 11 46mm captures (416x496 — the exact watch
  App Store size; upload raw to the watch slot).
- `template.html` / `template-watch.html` + `render.sh` — compositor rendered
  by headless Chrome at exact store resolution into `final/`.
- Captions are ASO copy on purpose — Apple OCR-indexes screenshot text.

Re-render after UI changes: recapture raws, then `marketing/appstore/render.sh`.
