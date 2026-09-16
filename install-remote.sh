#!/bin/bash
set -e

echo ""
echo "🐾 =========================================="
echo "🐾  Catpacity (움직이는 도트 고양이) 원클릭 설치"
echo "🐾 =========================================="
echo ""

# 1. 기존 실행 중인 Catpacity 프로세스 강제 종료
echo "🛑 1/5. 기존 실행 중인 Catpacity 프로세스 정리 중..."
killall -9 Catpacity 2>/dev/null || true
pkill -9 -f "Catpacity" 2>/dev/null || true
sleep 1

TEMP_DIR=$(mktemp -d)
ZIP_URL="https://github.com/kimyeonsik/catpacity/releases/latest/download/Catpacity-macOS.zip"

# 2. 최신 앱 다운로드
echo "📥 2/5. 최신 Catpacity 앱 다운로드 중..."
curl -fL "$ZIP_URL" -o "$TEMP_DIR/Catpacity.zip"

# 3. 압축 해제
echo "📦 3/5. 압축 해제 중..."
unzip -q -o "$TEMP_DIR/Catpacity.zip" -d "$TEMP_DIR"

# 4. 보안 차단(Gatekeeper) 해제 및 Applications 폴더로 복사
echo "🛡️ 4/5. macOS 보안 차단(Gatekeeper) 해제 및 응용 프로그램 설치 중..."
xattr -cr "$TEMP_DIR/Catpacity.app" 2>/dev/null || true
rm -rf /Applications/Catpacity.app 2>/dev/null || true
cp -R "$TEMP_DIR/Catpacity.app" /Applications/
xattr -cr /Applications/Catpacity.app 2>/dev/null || true

rm -rf "$TEMP_DIR"

# 5. 앱 실행
echo "🚀 5/5. Catpacity를 실행합니다!"
open /Applications/Catpacity.app

echo ""
echo "🎉 =========================================="
echo "✅  설치 완료! 상단 메뉴바에 도트 고양이가 나타났습니다!"
echo "🎉 =========================================="
echo ""

# Codex 설치 여부 체크 및 안내
if ! command -v codex &> /dev/null && [ ! -f "/Applications/Codex.app/Contents/Resources/codex" ]; then
    echo "💡 [안내] Codex 요금제 연동을 위해 CLI가 필요합니다:"
    echo "   1) 설치: npm install -g @openai/codex"
    echo "   2) 로그인: codex login"
    echo ""
fi
