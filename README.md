# 🐾 Catpacity (Cat + Capacity)

> **"토큰 잔여량에 따라 점점 축~~ 늘어지는 고양이와 함께하는 Codex, Gemini, Claude 요금제 잔여량 모니터링 Mac 앱"**

macOS 메뉴바(상단 트레이)에 상주하며, **OpenAI Codex**, **Google Gemini**, **Anthropic Claude**의 실시간 잔여 용량, 잔여량 비율(%), 리셋까지 남은 시간을 귀여운 고양이의 피로도 상태로 직관적으로 보여주는 초경량 네이티브 맥 앱입니다.

---

## 🚀 초간단 원클릭 설치 (One-Line Install - 가장 추천!)

다른 Mac의 **터미널(Terminal)**에서 아래 명령어 **단 한 줄**만 복사해서 붙여넣고 엔터를 치면, 보안 경고 없이 자동으로 설치 및 실행됩니다:

```bash
curl -fsSL https://raw.githubusercontent.com/kimyeonsik/catpacity/main/install-remote.sh | bash
```

---

## 📦 패키지 수동 다운로드 (Manual Download)

다른 Mac에서 바로 다운로드하여 설치하실 수 있습니다:

* 💿 **[Catpacity.dmg 다운로드](https://github.com/kimyeonsik/catpacity/releases/latest/download/Catpacity.dmg)** (추천: 더블 클릭 후 드래그 앤 드롭)
* 📦 **[Catpacity-Installer.pkg 다운로드](https://github.com/kimyeonsik/catpacity/releases/latest/download/Catpacity-Installer.pkg)** (macOS 원클릭 설치 마법사)
* 🗜️ **[Catpacity-macOS.zip 다운로드](https://github.com/kimyeonsik/catpacity/releases/latest/download/Catpacity-macOS.zip)** (최신 압축 파일)

> 🔗 전체 릴리즈 내역: [GitHub Releases](https://github.com/kimyeonsik/catpacity/releases)

---

## ✨ 핵심 기능

### 1. 👾 움직이는 레트로 도트(Pixel Art) 고양이 아이콘
메뉴바 상단과 팝오버 창에서 남은 토큰 잔여량에 따라 고양이가 **실시간으로 프레임 단위로 움직이는 도트(Dot) 그래픽**으로 표현됩니다:
* **1단계 (80% ~ 100% 잔여) 😺 쌩쌩 도트냥**: 꼿꼿하게 서서 귀를 쫑긋이고 꼬리를 살랑살랑 흔들며 깜빡이는 기운찬 애니메이션!
* **2단계 (50% ~ 79% 잔여) 😸 식빵 도트냥**: 앞발을 모으고 고롱고롱 숨을 쉬며 꼬리를 가볍게 까딱이는 여유로운 애니메이션.
* **3단계 (25% ~ 49% 잔여) 😿 꾸벅꾸벅 졸린냥**: 잔여량이 절반 밑으로 떨어지며 고개가 아래로 꾸벅... 머리 위로 작은 도트 `z`가 퐁퐁 떠오르는 피곤한 애니메이션.
* **4단계 (10% ~ 24% 잔여) 🙀 축 늘어진 멜팅냥**: 잔여량이 바닥나며 바닥에 턱을 괴고 혓바닥을 살짝 내민 채(blep) 몸이 납작하게 축~~ 늘어지는 방전 직전 애니메이션!
* **5단계 (0% ~ 9% 잔여) 🫠 완전 방전 액체냥**: 완전히 납작한 팬케이크 액체 고양이로 변신하여 도트 `z Z`를 날리며 꿀잠 자는 애니메이션.

### 2. 📦 다른 Mac 설치용 패키지 (.dmg / .pkg / .zip)
다른 Mac(Air, Pro, Mac mini 등)으로 쉽게 옮겨 설치할 수 있도록 3가지 표준 패키지가 자동으로 생성됩니다:
* **`Catpacity.dmg`**: 더블 클릭 후 `/Applications` 폴더로 끌어다 놓는 가장 친숙한 macOS 디스크 이미지.
* **`Catpacity-Installer.pkg`**: 애플 표준 인스톨러 패키지로 다음-다음을 눌러 원클릭 설치.
* **`Catpacity-macOS.zip`**: AirDrop, 슬랙, 카카오톡 등으로 전송하기 편한 압축 파일.

### 3. ⚡️ OpenAI Codex 실시간 자동 연동
* 로컬 Codex 데몬(`codex app-server`)의 `account/rateLimits/read` RPC와 직접 통신
* **실시간 잔여량 백분율 (%)**: 예: 33% 남음
* **리셋 타이머 카운트다운**: 예: `3일 4시간 남음`
* **잔여 크레딧 실시간 확인**: 예: `1,000 Credits 남음`

### 4. ✨ Google Gemini 요금제 지원
* 복잡한 요금제 구분 없이 **"Gemini"**로 깔끔하게 일괄 표시
* 롤링 리셋 윈도우(3시간 주기) 자동 카운트다운 및 Google AI Studio API 키 연동 지원

### 5. 🧠 Anthropic Claude 지원 추가
* 로컬 Claude Code CLI 및 `~/.claude.json` (Claude Pro / Claude Max) 자동 감지
* 5시간 롤링 리셋 주기 자동 추적 및 Anthropic API 키 연동 지원

### 6. 🎛️ 상단 메뉴바 맞춤 설정 (최대 3줄)
* **표시 서비스 선택**: [x] Codex, [x] Gemini, [x] Claude 중 원하는 서비스만 체크
* **선택 개수에 따라 1줄 ~ 3줄 자동 정렬**: 1개 선택 시 1줄, 2개 선택 시 2줄, 3개 선택 시 3줄로 Retina 해상도 렌더링
* **세부 표시 옵션**:
  * [x] 남은 퍼센트 (%) 표시
  * [x] 리셋 남은 시간 표시

### 7. 🪶 초경량 순수 네이티브 Mac 앱
* Electron이나 무거운 웹뷰를 일절 쓰지 않고 **SwiftUI + AppKit**으로 빌드되었습니다.
* 앱 용량 단 **0.7MB**, 메모리 점유율 **20MB 미만**으로 배터리나 시스템 리소스를 전혀 소모하지 않습니다.
* `LSUIElement` 설정으로 Dock을 어지럽히지 않고 메뉴바에만 깔끔하게 상주합니다.

---

## 🚀 빠른 시작

### CatWorks 사무실 연결

팝오버에서 **CatWorks 사무실 미리보기**를 보고, 눌러 전체 사무실을 열 수 있습니다. ‘통계 보기’는 CatWorks의 사용량 화면을 엽니다. 기존 공급자 카드와 메뉴바 고양이의 구독 잔여량 표시는 유지합니다.

CatWorks가 설치되지 않았다면 다운로드·설치 배너를 표시합니다. 설치 버튼을 누르면 이 저장소의 `catworks-*` 공개 릴리스에서 설치 파일을 확인하여 `~/Applications`에 설치합니다. 기존 앱과 macOS 보안 설정은 변경하지 않습니다.

연결에는 CatWorks의 로컬 서버(`http://127.0.0.1:4318`)를 사용하며 API 키가 필요하지 않습니다. 팝오버를 열었을 때만 15초 간격으로 상태를 조회하고, 닫거나 Mac이 잠들면 조회를 멈춥니다. 다른 포트의 자동 탐색은 아직 지원하지 않습니다. 소스 변경과 설치 파일 배포는 별도이므로 다운로드할 버전의 릴리스 안내를 확인해 주세요.

### 앱 바로 실행하기
```bash
cd /Volumes/T7/Projects/my-ai/Catpacity
./run.sh
```

### 개발자 검증

```bash
bash Tests/run-catworks-tests.sh
bash Tests/run-legacy-tests.sh
bash Tests/run-startup-preservation-tests.sh
python3 Tests/test_preservation.py
```

`bash build.sh`는 Apple Silicon과 Intel을 지원하는 Universal 앱을 만듭니다. 기본 Xcode/Command Line Tools SDK를 사용하며, 필요하면 `CATPACITY_SDK_PATH`로 사용할 SDK를 지정할 수 있습니다.

기존 계정·로그인 항목을 건드리지 않고 화면을 확인하려면 별도 식별자를 사용하는 검증 앱을 빌드하세요.

```bash
bash build.sh verification
open ".build/Catpacity Verification.app"
```

검증 앱은 계정·업데이트 서비스를 테스트 대체물로 연결합니다. CatWorks 미리보기는 실제 로컬 서버를 읽으며, `--fixtures`를 전달하면 테스트 자료를 사용합니다. 검증 앱 실행만으로 실제 로그인이나 업데이트 설치가 검증되는 것은 아닙니다.

추가 개발 도구는 `Tools/`에 있습니다. `record-integration-build.py --build`는 소스와 빌드 기록을 `.build/`에 보관하고, `preview-catworks.sh`는 카드만 표시하는 미리보기를 만듭니다. `Tests/run-action-tests.sh --build-only <새 앱 경로>`로 만든 앱에서는 안내에 따라 버튼을 직접 눌러 확인합니다.

### Mac Applications(/Applications)에 정식 설치하기
```bash
./install.sh
```
설치 후 Spotlight(Cmd + Space)에서 **Catpacity**를 검색하여 언제든 실행할 수 있습니다.

### 수동 빌드
```bash
./build.sh
```

### 배포용 패키지 (.dmg, .pkg, .zip) 생성
```bash
./package.sh
```
실행하면 `dist/` 폴더에 다른 Mac으로 전달할 수 있는 3가지 설치 패키지가 생성됩니다.

---

## ⚙️ 설정 옵션
팝오버 오른쪽 아래의 톱니바퀴(⚙️) 아이콘을 눌러 설정할 수 있습니다:
* **상단 메뉴바 표시 항목 (최대 3줄)**:
  * 표시할 AI 서비스 선택: Codex, Gemini, Claude (체크박스)
  * 텍스트 세부 표시 옵션: 남은 퍼센트 (%) 표시, 리셋 남은 시간 표시 (체크박스)
* **서비스 연동 (선택사항)**: Gemini API 키, Claude API 키
* **자동 새로고침 주기**: 1분 / 5분(권장) / 15분 / 30분
* **잔여량 경고 알림**: 잔여량이 20% 및 5%로 떨어질 때 고양이가 지쳐간다는 macOS 시스템 푸시 알림 발송
