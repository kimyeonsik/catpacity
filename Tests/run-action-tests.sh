#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "${1:-}" = --build-only ] && [ "$#" = 2 ]; then
  # A launchable test bundle can use the permitted GUI session without shell escalation.
  TEST_APP="$2"
  mkdir "$TEST_APP"
  mkdir -p "$TEST_APP/Contents/MacOS"
  cat > "$TEST_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.yeonsik.catpacity.action-tests</string>
<key>CFBundleExecutable</key><string>action-tests</string>
<key>CFBundleName</key><string>Catpacity Action Tests</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
  TEST_DIR="$TEST_APP/Contents/MacOS"
elif [ "$#" = 0 ]; then
  TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/catpacity-action-tests.XXXXXX")"
  trap 'rm -rf "$TEST_DIR"' EXIT
else
  echo 'Usage: run-action-tests.sh [--build-only <new-app-path>]' >&2
  exit 2
fi
SDK_PATH="${CATPACITY_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
xcrun swiftc -sdk "$SDK_PATH" -module-cache-path "${CATPACITY_MODULE_CACHE_PATH:-$ROOT/.build/module-cache}" -parse-as-library -target "$(uname -m)-apple-macos13.0" \
  "$ROOT"/Sources/Models/*.swift "$ROOT"/Sources/Views/*.swift \
  "$ROOT/Sources/Helpers/TimeFormatter.swift" "$ROOT/Sources/Helpers/PowerHelper.swift" \
  "$ROOT/Sources/Services/CatWorksService.swift" "$ROOT/Sources/Services/CatWorksInstaller.swift" \
  "$ROOT/Sources/Services/UpdateCheckerService.swift" \
  "$ROOT/Tests/LegacyActionDoubles.swift" "$ROOT/Tests/LegacyActionTests.swift" \
  -o "$TEST_DIR/action-tests"
if [ "${1:-}" = --build-only ]; then
  codesign --force --sign - "$TEST_APP"
  codesign --verify --deep --strict "$TEST_APP"
  echo "Built isolated GUI tests: $TEST_APP"
else
  "$TEST_DIR/action-tests"
fi
