#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT="$ROOT/test-results/reminders"
mkdir -p "$OUTPUT"
xcrun swiftc -module-cache-path "$OUTPUT/swift-cache" \
  "$ROOT/native/ios/Shared/PetSnapshot.swift" "$ROOT/native/ios/App/PetReminderPlan.swift" \
  "$ROOT/tests/native_reminders/main.swift" -o "$OUTPUT/test-reminders"
"$OUTPUT/test-reminders"
xcrun swiftc -parse-as-library -module-cache-path "$OUTPUT/swift-cache" \
  "$ROOT/native/ios/Shared/PetSnapshot.swift" "$ROOT/native/ios/App/PetReminderPlan.swift" \
  "$ROOT/native/ios/App/PetReminderController.swift" "$ROOT/tests/native_reminders/controller.swift" \
  -o "$OUTPUT/test-controller"
"$OUTPUT/test-controller"
xcrun --sdk iphoneos swiftc -warnings-as-errors -typecheck -target arm64-apple-ios16.0 \
  -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" -module-cache-path "$OUTPUT/ios-cache" \
  "$ROOT/native/ios/Shared/PetSnapshot.swift" "$ROOT/native/ios/App/PetReminderPlan.swift" \
  "$ROOT/native/ios/App/PetReminderController.swift" "$ROOT/native/ios/App/PetWidgetBridge.swift"
