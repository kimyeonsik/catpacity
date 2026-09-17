#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

DIST_DIR="$SCRIPT_DIR/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "🐱 최신 버전 Catpacity 빌드 중..."
"$SCRIPT_DIR/build.sh"

APP_PATH="$SCRIPT_DIR/Catpacity.app"
APP_NAME="Catpacity"
VERSION="1.2.4"

echo "📦 1. macOS Installer Package (.pkg) 생성 중..."
pkgbuild \
    --component "$APP_PATH" \
    --install-location "/Applications" \
    --identifier "com.yeonsik.catpacity" \
    --version "$VERSION" \
    "$DIST_DIR/${APP_NAME}-Installer.pkg"

echo "💿 2. 드래그 앤 드롭 설치용 .dmg 디스크 이미지 생성 중..."
DMG_STAGING="$DIST_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Add one-click gatekeeper bypass helper
cat << 'EOF' > "$DMG_STAGING/실행_안될때_더블클릭.command"
#!/bin/bash
echo "🐾 Catpacity 보안 차단을 해제합니다..."
if [ ! -d "/Applications/Catpacity.app" ]; then
    echo "📁 먼저 Catpacity.app을 Applications 폴더로 복사합니다..."
    cp -R "$(dirname "$0")/Catpacity.app" /Applications/
fi
xattr -cr /Applications/Catpacity.app 2>/dev/null || true
echo "🚀 Catpacity를 실행합니다!"
open /Applications/Catpacity.app
echo "✅ 완료! 이 창을 닫으셔도 됩니다."
sleep 2
EOF
chmod +x "$DMG_STAGING/실행_안될때_더블클릭.command"

cat << 'EOF' > "$DMG_STAGING/설치_및_실행_안내.txt"
🐾 Catpacity 설치 및 실행 방법:

1. 'Catpacity.app'을 오른쪽의 'Applications' 폴더로 드래그하세요.
2. 응용 프로그램에서 실행했을 때 "악성 코드가 없음을 확인할 수 없습니다" 경고가 뜨면:
   - 방법 A: '실행_안될때_더블클릭.command' 파일을 더블 클릭하면 자동으로 해결 및 실행됩니다!
   - 방법 B: 맥 [시스템 설정] > [개인정보 보호 및 보안] > 아래로 스크롤하여 [확인 없이 열기] 클릭
   - 방법 C: Applications 폴더의 Catpacity를 'Control' 키 누른 채 클릭(우클릭) > [열기] 클릭
EOF

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DIST_DIR/${APP_NAME}.dmg"

rm -rf "$DMG_STAGING"

echo "🗜️ 3. 공유/전송용 .zip 압축 파일 생성 중..."
cd "$SCRIPT_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_DIR/${APP_NAME}-v${VERSION}-macOS.zip"
cp "$DIST_DIR/${APP_NAME}-v${VERSION}-macOS.zip" "$DIST_DIR/${APP_NAME}-macOS.zip"

echo ""
echo "🎉 패키지 제작 완료! 배포 파일 목록 ($DIST_DIR):"
ls -lh "$DIST_DIR"
