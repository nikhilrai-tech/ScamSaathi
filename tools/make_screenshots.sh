#!/usr/bin/env bash
# Build the web app, serve it locally and take phone-sized screenshots with headless Chrome.
# Usage: tools/make_screenshots.sh [output_dir]      needs: flutter, python3, google-chrome
set -euo pipefail
OUT="${1:-/tmp/scamsaathi-shots}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$OUT"
(cd "$ROOT/app" && flutter build web --release --no-web-resources-cdn >/dev/null)
(cd "$ROOT/app/build/web" && python3 -m http.server 8081 >/dev/null 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
sleep 2
shot() { # name, query
  google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars --force-prefers-reduced-motion \
    --window-size=430,1500 --virtual-time-budget=20000 --screenshot="$OUT/$1.png" "http://localhost:8081/$2" >/dev/null 2>&1
}
shot home      "?lang=en&theme=light"
shot kyc-hi    "?sample=0&lang=hi&theme=light"
shot apk-en    "?sample=1&lang=en&theme=light"
shot upi-en    "?sample=2&lang=en&theme=light"
shot ok-hi     "?sample=3&lang=hi&theme=light"
shot kyc-dark  "?sample=0&lang=en&theme=dark"
echo "screenshots in $OUT"
