#!/bin/bash
set -euo pipefail

YOMU_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$YOMU_PROJECT_ROOT"
YOMU_BUILD_DIR="$YOMU_PROJECT_ROOT/.build/Mac"
YOMU_OUTPUT="$YOMU_PROJECT_ROOT/Dist/Yomu.app"

# Build for this Mac with a local signature; no Apple account is required.
xcodebuild -project Yomu.xcodeproj -scheme Yomu -configuration Release \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -derivedDataPath "$YOMU_BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build

mkdir -p "$YOMU_PROJECT_ROOT/Dist"
# Preserve previous generated apps; the library is stored separately.
if [ -e "$YOMU_OUTPUT" ]; then
    YOMU_PREVIOUS="$YOMU_PROJECT_ROOT/Dist/Yomu-previous-$(date +%Y%m%d-%H%M%S).app"
    mv "$YOMU_OUTPUT" "$YOMU_PREVIOUS"
fi
ditto "$YOMU_BUILD_DIR/Build/Products/Release-maccatalyst/Yomu.app" "$YOMU_OUTPUT"
codesign --force --sign - --entitlements App/YomuMac.entitlements "$YOMU_OUTPUT"
codesign --verify --deep --strict "$YOMU_OUTPUT"
printf '\nReady to open: %s\n' "$YOMU_OUTPUT"
