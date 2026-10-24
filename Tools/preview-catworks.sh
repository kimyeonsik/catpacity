#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
preview_bundle="$PWD/.build/CatWorks Preview.app"
mkdir -p "$preview_bundle/Contents/MacOS"
cat > "$preview_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CatWorksPreview</string>
<key>CFBundleIdentifier</key><string>com.yeonsik.catpacity.catworks-preview</string>
<key>CFBundleName</key><string>CatWorks Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xcrun swiftc -parse-as-library \
  Sources/Models/CatWorksSummary.swift Sources/Services/CatWorksService.swift Sources/Services/CatWorksInstaller.swift \
  Sources/Views/CatWorksCardView.swift Sources/Views/CatWorksOfficePreview.swift Tools/CatWorksPreview.swift \
  -o "$preview_bundle/Contents/MacOS/CatWorksPreview"
codesign --force --sign - "$preview_bundle"
printf 'Built isolated preview: %s\n' "$preview_bundle"
