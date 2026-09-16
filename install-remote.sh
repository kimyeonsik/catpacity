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
if ! curl -fL "$ZIP_URL" -o "$TEMP_DIR/Catpacity.zip" 2>/dev/null; then
    echo "   (직접 링크 연결 실패, 최신 릴리즈 정보에서 다운로드 탐색 중...)"
    FALLBACK_URL=$(curl -s "https://api.github.com/repos/kimyeonsik/catpacity/releases/latest" | grep "browser_download_url.*macOS\.zip" | head -n 1 | cut -d '"' -f 4)
    if [ -n "$FALLBACK_URL" ]; then
        curl -fL "$FALLBACK_URL" -o "$TEMP_DIR/Catpacity.zip"
    else
        echo "❌ 다운로드에 실패했습니다. 인터넷 연결 또는 GitHub 릴리즈 상태를 확인해주세요."
        exit 1
    fi
fi

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
echo "💡 [AI 연동 안내]"
echo " • OpenAI Codex : 'codex login'으로 자동 연동"
echo " • Anthropic Claude : 'claude login' 또는 설정에서 API 키 입력"
echo " • Google Gemini : Antigravity CLI 로그인 또는 설정에서 API 키 입력"
echo ""
