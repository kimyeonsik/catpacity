# 📜 Changelog

All notable changes to **Catpacity** will be documented in this file.
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.1] - 2026-09-16

### 🐛 Bug Fixes & Improvements
- **Antigravity CLI 실시간 쿼터 연동**:
  - Google Gemini 쿼터를 Antigravity CLI(`agy -p /quota`)와 직접 연동하여 실제 5시간 한도 잔여량 및 주간 한도를 실시간 동기화.
- **CLI 환경 변수(PATH, HOME) 주입 (EnvironmentHelper)**:
  - macOS GUI LaunchServices 환경에서 `node`, `codex`, `agy`, `claude` 바이너리를 안정적으로 실행할 수 있도록 환경 변수 자동 보정.
  - Codex 통신 시 발생하던 '요청 시간 초과 (Timeout)' 문제 해결.
- **Claude 구독 해지 및 비로그인 상태 정확 반영**:
  - `~/.claude.json`의 과거 Max 플랜 캐시를 맹목적으로 신뢰하지 않고 `claude auth status`로 활성 로그인 여부를 실시간 교차 검증.
  - 구독 해지 시 `미연동 (구독 없음 / 로그아웃됨)`으로 정확히 표시.
- **GitHub 릴리즈 기반 무서버 자동 업데이트 알림**:
  - 최신 버전 발견 시 macOS 시스템 알림 및 앱 내 배너 표시.

---

## [1.1.0] - 2026-09-16

### 🚀 Major Highlights
- **3대 주요 AI 전면 지원 (Codex + Gemini + Claude)**:
  - 기존 Codex, Gemini에 더해 **Anthropic Claude** 공식 지원 추가.
  - Mac에 설치된 Claude Code (`~/.claude.json`) 유료 플랜(Claude Pro / Claude Max) 자동 감지.
  - Claude의 5시간 롤링 리셋 윈도우 실시간 카운트다운 추적.
- **메뉴바 다이내믹 멀티라인 렌더링 (최대 3줄)**:
  - 설정에서 표시할 서비스를 체크박스로 선택 (`Codex`, `Gemini`, `Claude`).
  - 선택한 서비스 개수에 맞춰 1줄 ~ 최대 3줄로 Retina 2x 고해상도 자동 정렬.
- **표시 세부항목 선택 옵션**:
  - `[x] 남은 퍼센트 (%) 표시` 및 `[x] 리셋 남은 시간 표시` 체크박스 분리 제공.
- **잔여량(Remaining Capacity) 패러다임 전면 개편**:
  - 사용량(소진율) 기준에서 **남은 용량(잔여량)** 기준으로 모든 UI/게이지/알림 변경.
- **Gemini 명칭 단순화**:
  - 복잡한 요금제 명칭 대신 간결하게 `Gemini`로 일괄 통일.
- **시뮬레이션 슬라이더 완전 제거**:
  - 혼란을 주던 수동 조절 슬라이더를 걷어내고 순수 실시간 자동 모니터링 체제로 정돈.

### 📦 Packaging & Distribution
- `Catpacity.dmg` 내에 보안 차단 해제 원클릭 스크립트(`실행_안될때_더블클릭.command`) 동봉.
- 영구 고정 `latest` 다운로드 링크(`Catpacity-macOS.zip`) 도입으로 원클릭 스크립트 영구 호환성 확보.

---

## [1.0.0] - 2026-09-16

### 🎉 Initial Release
- **레트로 도트(Pixel Art) 고양이 애니메이션**:
  - 5단계 피로도(쌩쌩냥 -> 식빵냥 -> 졸린냥 -> 멜팅냥 -> 액체냥) 실시간 애니메이션 엔진.
- **OpenAI Codex 연동**:
  - 로컬 `codex app-server` RPC 직접 통신 및 서브 모델 / 크레딧 잔여량 조회.
- **Google Gemini 연동**:
  - Google AI Studio API 키 연동 및 Google One 롤링 리셋 윈도우 추적.
- **macOS 패키징**:
  - `.dmg`, `.pkg`, `.zip` 3종 배포 패키지 및 `install-remote.sh` 원클릭 터미널 설치 지원.
