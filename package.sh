#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

DIST_DIR="$SCRIPT_DIR/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# 1. Ensure latest build
echo "🐱 최신 버전 Catpacity 빌드 중..."
"$SCRIPT_DIR/build.sh"

APP_PATH="$SCRIPT_DIR/Catpacity.app"
APP_NAME="Catpacity"
VERSION="1.0.0"

# 2. Build macOS Installer Package (.pkg)
echo "📦 1. 다른 Mac에 원클릭 설치 가능한 .pkg 패키지 생성 중..."
pkgbuild \
    --component "$APP_PATH" \
    --install-location "/Applications" \
    --identifier "com.yeonsik.catpacity" \
    --version "$VERSION" \
    "$DIST_DIR/${APP_NAME}-Installer.pkg"

# 3. Build macOS Disk Image (.dmg) with drag-and-drop to Applications
echo "💿 2. 드래그 앤 드롭 설치용 .dmg 디스크 이미지 생성 중..."
DMG_STAGING="$DIST_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Add a friendly README in the DMG
cat << 'EOF' > "$DMG_STAGING/설치방법.txt"
🐾 Catpacity 설치 방법:
1. 'Catpacity.app'을 오른쪽의 'Applications' 폴더로 드래그하여 끌어다 놓으세요.
2. Applications(응용 프로그램) 폴더에서 Catpacity를 더블 클릭하여 실행하세요.
3. 상단 메뉴바에 귀여운 움직이는 도트 고양이가 나타납니다!

* 다른 Mac에서 "확인되지 않은 개발자" 경고가 발생할 경우:
- 마우스 우클릭 > [열기] 클릭 후 [열기] 버튼을 누르거나
- 터미널에서: xattr -cr /Applications/Catpacity.app 실행
EOF

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DIST_DIR/${APP_NAME}.dmg"

rm -rf "$DMG_STAGING"

# 4. Build ZIP Archive (.zip)
echo "🗜️ 3. 공유/전송용 .zip 압축 파일 생성 중..."
cd "$SCRIPT_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_DIR/${APP_NAME}-v${VERSION}-macOS.zip"

echo ""
echo "🎉 패키지 제작 완료! 배포 파일 목록 ($DIST_DIR):"
ls -lh "$DIST_DIR"
