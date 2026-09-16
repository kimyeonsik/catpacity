# 🐾 Catpacity (Cat + Capacity)

> **"토큰 잔여량에 따라 점점 축~~ 늘어지는 고양이와 함께하는 Gemini & Codex 요금제 잔여량 모니터링 Mac 앱"**

macOS 메뉴바(상단 트레이)에 상주하며, **OpenAI Codex** 및 **Google Gemini**의 실시간 잔여 용량, 잔여량 비율(%), 리셋까지 남은 시간을 귀여운 고양이의 피로도 상태로 직관적으로 보여주는 초경량 네이티브 맥 앱입니다.

---

## 🚀 초간단 원클릭 설치 (One-Line Install - 가장 추천!)

다른 Mac의 **터미널(Terminal)**에서 아래 명령어 **단 한 줄**만 복사해서 붙여넣고 엔터를 치면, 보안 경고 없이 자동으로 설치 및 실행됩니다:

```bash
curl -fsSL https://raw.githubusercontent.com/kimyeonsik/catpacity/main/install-remote.sh | bash
```

---

## 📦 패키지 수동 다운로드 (Manual Download)

다른 Mac에서 바로 다운로드하여 설치하실 수 있습니다:

* 💿 **[Catpacity.dmg 다운로드](https://github.com/kimyeonsik/catpacity/releases/download/v1.0.0/Catpacity.dmg)** (추천: 더블 클릭 후 드래그 앤 드롭)
* 📦 **[Catpacity-Installer.pkg 다운로드](https://github.com/kimyeonsik/catpacity/releases/download/v1.0.0/Catpacity-Installer.pkg)** (macOS 원클릭 설치 마법사)
* 🗜️ **[Catpacity-v1.0.1-macOS.zip 다운로드](https://github.com/kimyeonsik/catpacity/releases/download/v1.0.0/Catpacity-v1.0.1-macOS.zip)** (압축 파일)

> 🔗 전체 릴리즈 페이지: [GitHub Releases v1.0.0](https://github.com/kimyeonsik/catpacity/releases/tag/v1.0.0)

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
* **`Catpacity-v1.0.0-macOS.zip`**: AirDrop, 슬랙, 카카오톡 등으로 전송하기 편한 압축 파일.

### 3. ⚡️ OpenAI Codex 실시간 자동 연동
* 로컬 Codex 데몬(`codex app-server`)의 `account/rateLimits/read` RPC와 직접 통신
* **실시간 사용량 백분율 (%)**: 예: 67% 소진 / 33% 남음
* **리셋 타이머 카운트다운**: 예: `3일 4시간 남음 (9월 18일 오후 8:57)`
* **잔여 크레딧 실시간 확인**: 예: `1,000 Credits 남음`
* **서브 모델 상태 표기**: Spark 등 개별 모델 사용량

### 3. ✨ Google Gemini 요금제 지원
* **Gemini Advanced (Google One 2TB)** 플랜 지원 및 롤링 리셋 윈도우 추적
* **Google AI Studio (Gemini API Key)** 설정 지원 (TPM/RPM 잔여 헤더 자동 동기화)
* 다음 리셋 시점까지의 정밀 카운트다운 제공

### 4. 🧪 인터랙티브 고양이 시뮬레이터
* 팝오버 하단의 눈 모양(👁) 버튼을 누르면 테스트 슬라이더가 나타납니다.
* 슬라이더를 0%부터 100%까지 자유롭게 움직여 5가지 고양이 변신 애니메이션과 귀여운 대사를 미리 볼 수 있습니다!

### 5. 🪶 초경량 순수 네이티브 Mac 앱
* Electron이나 무거운 웹뷰를 일절 쓰지 않고 **SwiftUI + AppKit**으로 빌드되었습니다.
* 앱 용량 단 **0.7MB**, 메모리 점유율 **20MB 미만**으로 배터리나 시스템 리소스를 전혀 소모하지 않습니다.
* `LSUIElement` 설정으로 Dock을 어지럽히지 않고 메뉴바에만 깔끔하게 상주합니다.

---

## 🚀 빠른 시작

### 앱 바로 실행하기
```bash
cd /Volumes/T7/Projects/my-ai/Catpacity
./run.sh
```

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
* **상단 표시 형식**:
  * **고양이 + 2줄 상세 (Codex & Gemini 잔여량 / 리셋 시간)** (추천!)
  * 고양이 아이콘만 표시 (미니멀)
  * 고양이 + 최소 잔여량 (%) 표시
  * 고양이 + 리셋 남은 시간 표시
* **자동 새로고침 주기**: 1분 / 5분(권장) / 15분 / 30분
* **잔여량 경고 알림**: 잔여량이 20% 및 5%로 떨어질 때 고양이가 지쳐간다는 macOS 시스템 푸시 알림 발송
* **Google AI 공식 요금제 설정**:
  * `Google AI Pro (5 TB)` / `Google AI Plus (400 GB)` / `Google AI Ultra (20 TB)`
  * `Google One AI 프리미엄 (2 TB)` / `Google AI Studio API` / `직접 입력(커스텀)` 지원
