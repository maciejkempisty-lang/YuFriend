#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
EXPORT_DIR=${1:-"$ROOT/exports/ios-widget-v8"}
mkdir -p "$EXPORT_DIR"
EXPORT_DIR=$(CDPATH= cd -- "$EXPORT_DIR" && pwd)
"$GODOT_BIN" --headless --path "$ROOT" --log-file "$EXPORT_DIR/export.log" \
  --export-debug 'iOS Gloria Playtest' "$EXPORT_DIR/YuFriend.zip"
python3 "$ROOT/tools/install_ios_widget.py" "$EXPORT_DIR/YuFriend.xcodeproj" --godot "$GODOT_BIN"
