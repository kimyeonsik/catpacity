#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_PATH="$SCRIPT_DIR/Catpacity.app"

if [ ! -d "$APP_PATH" ]; then
    echo "📦 Catpacity.app 빌드 중..."
    "$SCRIPT_DIR/build.sh"
fi

echo "🚀 /Applications 폴더에 Catpacity.app을 복사합니다..."
rm -rf "/Applications/Catpacity.app"
cp -R "$APP_PATH" "/Applications/Catpacity.app"

echo "✅ 설치가 완료되었습니다! Applications에서 실행하거나 'open /Applications/Catpacity.app'을 입력하세요."
