#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/catworks-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
SDK_PATH="${CATPACITY_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
xcrun swiftc -sdk "$SDK_PATH" -module-cache-path "${CATPACITY_MODULE_CACHE_PATH:-$ROOT/.build/module-cache}" -parse-as-library -target "$(uname -m)-apple-macos13.0" \
  "$ROOT/Sources/Models/CatWorksSummary.swift" \
  "$ROOT/Sources/Services/CatWorksService.swift" \
  "$ROOT/Tests/CatWorksTests.swift" -o "$TEST_DIR/catworks-tests"
"$TEST_DIR/catworks-tests"
