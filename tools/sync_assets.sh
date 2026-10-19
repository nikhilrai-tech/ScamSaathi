#!/usr/bin/env bash
# packs/core/pack.json is the single source of truth. Copy it to where it is bundled (app asset, engine package data).
# Tests fail if a copy drifts, so run this after every pack change.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cp "$ROOT/packs/core/pack.json" "$ROOT/app/assets/pack.json"
cp "$ROOT/packs/core/pack.json" "$ROOT/engine/scamsaathi/data/pack.json"
cp "$ROOT/packs/keys/release.pub" "$ROOT/app/assets/release.pub"
cp "$ROOT/packs/core/apk/fake_pmkisan.apk" "$ROOT/packs/core/apk/torch_ok.apk" "$ROOT/app/assets/apk/"
cp "$ROOT/LICENSE" "$ROOT/engine/LICENSE"
cp "$ROOT/NOTICE" "$ROOT/engine/NOTICE"
echo "assets synced"
