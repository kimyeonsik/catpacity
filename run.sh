#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_PATH="$SCRIPT_DIR/Catpacity.app"

if [ ! -d "$APP_PATH" ]; then
    echo "📦 Catpacity.app을 먼저 빌드합니다..."
    "$SCRIPT_DIR/build.sh"
fi

echo "🐾 Catpacity를 실행합니다!"
open "$APP_PATH"
