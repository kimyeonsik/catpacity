#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/catpacity-legacy-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
SDK_PATH="${CATPACITY_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
xcrun swiftc -sdk "$SDK_PATH" -module-cache-path "${CATPACITY_MODULE_CACHE_PATH:-$ROOT/.build/module-cache}" -parse-as-library -target "$(uname -m)-apple-macos13.0" \
  "$ROOT/Sources/Models/UsageData.swift" "$ROOT/Sources/Models/CatState.swift" \
  "$ROOT/Sources/Services/UpdateCheckerService.swift" "$ROOT/Sources/Services/NotificationService.swift" \
  "$ROOT/Tests/LegacyRegressionTests.swift" -o "$TEST_DIR/catpacity-legacy-regression"
"$TEST_DIR/catpacity-legacy-regression"
