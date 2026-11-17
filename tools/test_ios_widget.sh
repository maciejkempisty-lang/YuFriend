#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
OUTPUT="$ROOT/test-results/widget"
mkdir -p "$OUTPUT"
# Swift module caches embed absolute paths; key them by checkout so a moved
# project (e.g. another disk) never reuses a stale cache.
CACHE_KEY=$(printf %s "$ROOT" | shasum | cut -c1-12)
"$GODOT_BIN" --headless --path "$ROOT" --log-file "$OUTPUT/fixtures.log" \
  --script res://tests/widget_fixtures.gd -- "$OUTPUT/fixtures.json"
xcrun swiftc -module-cache-path "$OUTPUT/swift-cache-$CACHE_KEY" \
  "$ROOT/native/ios/Shared/PetSnapshot.swift" "$ROOT/tests/native_widget/main.swift" -o "$OUTPUT/test-widget"
"$OUTPUT/test-widget" "$OUTPUT/fixtures.json"
