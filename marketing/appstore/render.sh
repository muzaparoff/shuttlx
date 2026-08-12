#!/bin/bash
# Renders ShuttlX App Store marketing screenshots (6.9", 1320x2868) from raw
# simulator captures via headless Chrome. Captions are ASO copy — Apple
# OCR-indexes screenshot text.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW="$DIR/raw"
OUT="$DIR/final"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

render() { # out  template  headline  sub  shotA [shotB]
  local out="$1" tpl="$2" headline="$3" sub="$4" a="$5" b="${6:-}"
  local html="$TMP/$out.html"
  sed -e "s|HEADLINE_TEXT|$headline|" \
      -e "s|SUB_TEXT|$sub|" \
      -e "s|SHOT_SRC|file://$RAW/$a|" \
      -e "s|SHOT_A|file://$RAW/$a|" \
      -e "s|SHOT_B|file://$RAW/$b|" \
      "$DIR/$tpl" > "$html"
  "$CHROME" --headless --disable-gpu --force-device-scale-factor=1 \
      --window-size=1320,2868 --hide-scrollbars \
      --screenshot="$OUT/$out" "file://$html" 2>/dev/null
  echo "rendered $out"
}

render 01-mixtape.png  template.html       'Your run, <span class="accent">on tape</span>'        'The Walkman-style interval deck' timer-mixtape.png
render 02-watch.png    template-watch.html 'Built for <span class="accent">your wrist</span>'     'Start, run and finish from Apple Watch' watch-interval.png watch-mixtape.png
render 03-clean.png    template.html       'Interval coaching, <span class="accent">clear</span>' 'Work, rest, heart rate and pace at a glance' timer-clean.png
render 04-training.png template.html       'Your training <span class="accent">HQ</span>'         'Programs, history and analytics on iPhone' home.png

echo "Done: $(ls "$OUT" | wc -l | tr -d ' ') screenshots in $OUT"
