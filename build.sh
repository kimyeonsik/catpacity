#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

APP_NAME="Catpacity"
BUILD_MODE="${1:-product}"
SWIFT_FLAGS=(-O)
EXTRA_SOURCES=(Sources/Main.swift)
case "$BUILD_MODE" in
    product) BUNDLE_DIR="$SCRIPT_DIR/$APP_NAME.app" ;;
    verification)
        BUNDLE_DIR="$SCRIPT_DIR/.build/Catpacity Verification.app"
        SWIFT_FLAGS=(-O -D CATPACITY_VERIFICATION)
        EXTRA_SOURCES=(Sources/Main.swift Tools/IntegrationVerification.swift)
        ;;
    *) echo "Usage: bash build.sh [product|verification]" >&2; exit 2 ;;
esac
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"

echo "🐱 Building $APP_NAME for macOS..."

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$SCRIPT_DIR/Assets/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
if [ "$BUILD_MODE" = verification ]; then
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.yeonsik.catpacity.integration-verification' "$BUNDLE_DIR/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName Catpacity Verification' "$BUNDLE_DIR/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Catpacity Verification' "$BUNDLE_DIR/Contents/Info.plist"
fi
if [ -f "$SCRIPT_DIR/Assets/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
cp "$SCRIPT_DIR/Resources/install-catworks.sh" "$RESOURCES_DIR/install-catworks.sh"

SDK_PATH="${CATPACITY_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
MODULE_CACHE="${CATPACITY_MODULE_CACHE_PATH:-$SCRIPT_DIR/.build/module-cache}"

echo "⚡️ 1. Compiling Swift sources for Apple Silicon (arm64)..."
xcrun swiftc \
    -sdk "$SDK_PATH" \
    -module-cache-path "$MODULE_CACHE" \
    -target arm64-apple-macos13.0 \
    "${SWIFT_FLAGS[@]}" \
    -parse-as-library \
    -o "$MACOS_DIR/${APP_NAME}_arm64" \
    Sources/Models/*.swift \
    Sources/Helpers/*.swift \
    Sources/Services/*.swift \
    Sources/Views/*.swift \
    "${EXTRA_SOURCES[@]}"

echo "⚡️ 2. Compiling Swift sources for Intel (x86_64)..."
xcrun swiftc \
    -sdk "$SDK_PATH" \
    -module-cache-path "$MODULE_CACHE" \
    -target x86_64-apple-macos13.0 \
    "${SWIFT_FLAGS[@]}" \
    -parse-as-library \
    -o "$MACOS_DIR/${APP_NAME}_x86_64" \
    Sources/Models/*.swift \
    Sources/Helpers/*.swift \
    Sources/Services/*.swift \
    Sources/Views/*.swift \
    "${EXTRA_SOURCES[@]}"

echo "🔗 3. Creating Universal Binary (arm64 + x86_64)..."
lipo -create -output "$MACOS_DIR/$APP_NAME" "$MACOS_DIR/${APP_NAME}_arm64" "$MACOS_DIR/${APP_NAME}_x86_64"
rm -f "$MACOS_DIR/${APP_NAME}_arm64" "$MACOS_DIR/${APP_NAME}_x86_64"

echo "🔏 Applying ad-hoc code signature..."
codesign --force --sign - "$BUNDLE_DIR"
codesign --verify --deep --strict "$BUNDLE_DIR"
lipo -archs "$MACOS_DIR/$APP_NAME" | awk 'NF == 2 && /arm64/ && /x86_64/ { valid = 1 } END { exit !valid }'

echo "✅ Build Complete! App bundle located at: $BUNDLE_DIR"
