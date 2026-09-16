#!/bin/bash
set -e

echo "🐾 Catpacity (움직이는 도트 고양이) 설치를 시작합니다..."

TEMP_DIR=$(mktemp -d)
ZIP_URL="https://github.com/kimyeonsik/catpacity/releases/download/v1.0.0/Catpacity-v1.0.1-macOS.zip"

echo "📥 최신 Catpacity 다운로드 중..."
curl -fsSL "$ZIP_URL" -o "$TEMP_DIR/Catpacity.zip"

echo "📦 압축 해제 중..."
unzip -q -o "$TEMP_DIR/Catpacity.zip" -d "$TEMP_DIR"

echo "🛡️ macOS 보안 격리 속성(Gatekeeper) 자동 해제 중..."
xattr -cr "$TEMP_DIR/Catpacity.app" 2>/dev/null || true

echo "🚀 /Applications 폴더로 설치 중..."
rm -rf /Applications/Catpacity.app
cp -R "$TEMP_DIR/Catpacity.app" /Applications/
xattr -cr /Applications/Catpacity.app 2>/dev/null || true

rm -rf "$TEMP_DIR"

echo "🎉 설치 완료! Catpacity를 실행합니다..."
open /Applications/Catpacity.app

echo "✅ 상단 메뉴바에 귀여운 도트 고양이가 나타났습니다!"
