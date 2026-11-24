#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
if [ "${1:-}" = '--help' ]; then
  echo 'Usage: tools/export_android.sh [output-directory]'
  echo 'Requires Android export templates, SDK, JDK and a debug keystore configured in Godot.'
  exit 0
fi
EXPORT_DIR=${1:-"$ROOT/exports/android"}
mkdir -p "$EXPORT_DIR"
EXPORT_DIR=$(CDPATH= cd -- "$EXPORT_DIR" && pwd)
touch "$EXPORT_DIR/.gdignore"
"$GODOT_BIN" --headless --path "$ROOT" --editor --quit --log-file "$EXPORT_DIR/import.log"
"$GODOT_BIN" --headless --path "$ROOT" --log-file "$EXPORT_DIR/export.log" \
  --export-debug 'Android Playtest' "$EXPORT_DIR/YuFriend-debug.apk"
