#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT="$ROOT/test-results/reminders"
mkdir -p "$OUTPUT"
# Swift module caches embed absolute paths; key them by checkout so a moved
# project (e.g. another disk) never reuses a stale cache.
CACHE_KEY=$(printf %s "$ROOT" | shasum | cut -c1-12)
xcrun swiftc -module-cache-path "$OUTPUT/swift-cache-$CACHE_KEY" \
  "$ROOT/native/ios/Shared/PetSnapshot.swift" "$ROOT/native/ios/App/PetReminderPlan.swift" \
  "$ROOT/tests/native_reminders/main.swift" -o "$OUTPUT/test-reminders"
"$OUTPUT/test-reminders"
xcrun swiftc -parse-as-library -module-cache-path "$OUTPUT/swift-cache-$CACHE_KEY" \
  "$ROOT/native/ios/Shared/PetSnapshot.swift" "$ROOT/native/ios/App/PetReminderPlan.swift" \
  "$ROOT/native/ios/App/PetReminderController.swift" "$ROOT/tests/native_reminders/controller.swift" \
  -o "$OUTPUT/test-controller"
"$OUTPUT/test-controller"
xcrun --sdk iphoneos swiftc -warnings-as-errors -typecheck -target arm64-apple-ios16.0 \
  -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" -module-cache-path "$OUTPUT/ios-cache-$CACHE_KEY" \
  "$ROOT/native/ios/Shared/PetSnapshot.swift" "$ROOT/native/ios/App/PetReminderPlan.swift" \
  "$ROOT/native/ios/App/PetReminderController.swift" "$ROOT/native/ios/App/PetWidgetBridge.swift"
