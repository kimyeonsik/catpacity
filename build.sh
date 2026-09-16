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

SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
export DEVELOPER_DIR="/Library/Developer/CommandLineTools"

echo "⚡️ Compiling Swift sources..."
xcrun swiftc \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macos13.0 \
    -O \
    -parse-as-library \
    -o "$MACOS_DIR/$APP_NAME" \
    Sources/Models/*.swift \
    Sources/Helpers/*.swift \
    Sources/Services/*.swift \
    Sources/Views/*.swift \
    Sources/Main.swift

echo "🔏 Applying ad-hoc code signature..."
codesign --force --deep --sign - "$BUNDLE_DIR" 2>/dev/null || true

echo "✅ Build Complete! App bundle located at: $BUNDLE_DIR"
