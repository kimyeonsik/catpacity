#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

APP_NAME="Catpacity"
BUNDLE_DIR="$SCRIPT_DIR/$APP_NAME.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"

echo "🐱 Building $APP_NAME for macOS..."

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$SCRIPT_DIR/Assets/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
if [ -f "$SCRIPT_DIR/Assets/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
export DEVELOPER_DIR="/Library/Developer/CommandLineTools"

echo "⚡️ 1. Compiling Swift sources for Apple Silicon (arm64)..."
xcrun swiftc \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macos13.0 \
    -O \
    -parse-as-library \
    -o "$MACOS_DIR/${APP_NAME}_arm64" \
    Sources/Models/*.swift \
    Sources/Helpers/*.swift \
    Sources/Services/*.swift \
    Sources/Views/*.swift \
    Sources/Main.swift

echo "⚡️ 2. Compiling Swift sources for Intel (x86_64)..."
xcrun swiftc \
    -sdk "$SDK_PATH" \
    -target x86_64-apple-macos13.0 \
    -O \
    -parse-as-library \
    -o "$MACOS_DIR/${APP_NAME}_x86_64" \
    Sources/Models/*.swift \
    Sources/Helpers/*.swift \
    Sources/Services/*.swift \
    Sources/Views/*.swift \
    Sources/Main.swift

echo "🔗 3. Creating Universal Binary (arm64 + x86_64)..."
lipo -create -output "$MACOS_DIR/$APP_NAME" "$MACOS_DIR/${APP_NAME}_arm64" "$MACOS_DIR/${APP_NAME}_x86_64"
rm -f "$MACOS_DIR/${APP_NAME}_arm64" "$MACOS_DIR/${APP_NAME}_x86_64"

echo "🔏 Applying ad-hoc code signature..."
codesign --force --deep --sign - "$BUNDLE_DIR" 2>/dev/null || true

echo "✅ Build Complete! App bundle located at: $BUNDLE_DIR"
