import SwiftUI

public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject public var appState: AppState
    
    // Menu Bar Display Customization
    @AppStorage("catpacity_show_codex") private var showCodex: Bool = true
    @AppStorage("catpacity_show_gemini") private var showGemini: Bool = true
    @AppStorage("catpacity_show_claude") private var showClaude: Bool = true
    @AppStorage("catpacity_show_percent") private var showPercent: Bool = true
    @AppStorage("catpacity_show_reset_time") private var showResetTime: Bool = true
    
    // Cat Breed Customization
    @AppStorage("catpacity_selected_breed") private var selectedBreedRaw: String = "ginger_tabby"
    
    // Cat Status Target Customization
    @AppStorage("catpacity_cat_status_target") private var catStatusTarget: String = "min"
    
    // Energy & Battery Saver
    @AppStorage("catpacity_enable_menubar_animation") private var enableMenuBarAnimation: Bool = true
    @AppStorage("catpacity_pause_on_battery") private var pauseOnBattery: Bool = true
    @AppStorage("catpacity_animation_speed") private var animationSpeed: Double = 1.2
    
    // API Keys
    @AppStorage("catpacity_codex_api_key") private var codexApiKey: String = ""
    @AppStorage("catpacity_gemini_api_key") private var geminiApiKey: String = ""
    @AppStorage("catpacity_claude_api_key") private var claudeApiKey: String = ""
    
    // General
    @State private var launchAtLogin: Bool = LaunchAtLoginHelper.isEnabled
    @AppStorage("catpacity_refresh_interval") private var refreshInterval: Int = 300 // 5 mins
    @AppStorage("catpacity_notify_on_high_usage") private var notifyHighUsage: Bool = true
    
    let speedOptions: [(Double, String)] = [
        (1.5, "느긋하게 (초절전 - 1.5초)"),
        (1.2, "여유롭게 (권장 - 1.2초)"),
        (0.8, "보통 (0.8초)"),
        (0.4, "빠르게 (0.4초)")
    ]

    
    let refreshOptions = [
        (60, "1분마다"),
        (300, "5분마다 (권장)"),
        (900, "15분마다"),
        (1800, "30분마다")
    ]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("설정 ⚙️")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("완료") {
                    appState.updateMenuBar()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    // Section 1: AI Service Selection (Menu Bar & Popover)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("사용할 AI 서비스 선택")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.accentColor)
                        
                        Text("체크된 서비스만 메뉴바 및 말풍선에 표시됩니다:")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            Toggle("OpenAI Codex", isOn: $showCodex)
                                .font(.system(size: 11.5, weight: .medium))
                                .onChange(of: showCodex) { _ in
                                    appState.updateMenuBar()
                                    appState.objectWillChange.send()
                                }
                            
                            Toggle("Google Gemini", isOn: $showGemini)
                                .font(.system(size: 11.5, weight: .medium))
                                .onChange(of: showGemini) { _ in
                                    appState.updateMenuBar()
                                    appState.objectWillChange.send()
                                }
                            
                            Toggle("Anthropic Claude", isOn: $showClaude)
                                .font(.system(size: 11.5, weight: .medium))
                                .onChange(of: showClaude) { _ in
                                    appState.updateMenuBar()
                                    appState.objectWillChange.send()
                                }
                        }
                        .padding(.vertical, 2)
                
                Divider().opacity(0.4)
                
                Text("텍스트 세부 표시 옵션:")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    Toggle("남은 퍼센트 (%) 표시", isOn: $showPercent)
                        .font(.system(size: 11.5))
                        .onChange(of: showPercent) { _ in appState.updateMenuBar() }
                    
                    Toggle("리셋 남은 시간 표시", isOn: $showResetTime)
                        .font(.system(size: 11.5))
                        .onChange(of: showResetTime) { _ in appState.updateMenuBar() }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 2: Cat Breed Selection (반려묘 캐릭터 선택)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("🐱 반려묘 캐릭터 (품종) 선택")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Spacer()
                    if let currentBreed = CatBreed(rawValue: selectedBreedRaw) {
                        Text("\(currentBreed.emoji) \(currentBreed.shortName)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("나만의 고양이를 선택하세요. 쿼터 잔여량에 따라 해당 고양이의 표정과 상태가 변화합니다:")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(CatBreed.allCases) { breed in
                        let isSelected = (selectedBreedRaw == breed.rawValue)
                        Button(action: {
                            selectedBreedRaw = breed.rawValue
                            appState.selectedBreed = breed
                        }) {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                    PixelArtCanvas(stage: .energetic, breed: breed, frameIndex: 0)
                                        .padding(2)
                                }
                                .frame(width: 36, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 3) {
                                        Text(breed.emoji)
                                            .font(.system(size: 11))
                                        Text(breed.shortName)
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(.primary)
                                    }
                                    Text(breed.description)
                                        .font(.system(size: 8.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer(minLength: 0)
                                
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 13))
                                }
                            }
                            .padding(7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 3: Cat Status Target AI Service
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("고양이 표정 / 상태 기준 AI")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Spacer()
                    if !appState.activeTargetLabel.isEmpty {
                        Text("현재: \(appState.activeTargetLabel)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("메뉴바 아이콘 및 말풍선 상단 고양이의 피로도(애니메이션)를 결정할 기준을 선택합니다:")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                
                Picker("고양이 상태 기준", selection: $catStatusTarget) {
                    ForEach(CatStatusTarget.allCases) { target in
                        Text(target.displayName).tag(target.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: catStatusTarget) { _ in
                    appState.updateLineCache()
                    appState.updateMenuBar()
                    appState.objectWillChange.send()
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 3: Energy & Battery Saver
            VStack(alignment: .leading, spacing: 8) {
                Text("⚡️ 배터리 및 에너지 절약")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Toggle("상단 메뉴바 고양이 애니메이션 활성화", isOn: $enableMenuBarAnimation)
                    .font(.system(size: 11.5, weight: .medium))
                    .onChange(of: enableMenuBarAnimation) { _ in
                        appState.updateMenuBar()
                    }
                
                Text("체크 해제 시 정적 도트 아이콘을 유지하며 CPU 및 배터리를 전혀 소모하지 않습니다.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.leading, 18)
                    .padding(.bottom, 2)
                
                if enableMenuBarAnimation {
                    Divider().opacity(0.4)
                    
                    Toggle("맥북 배터리 사용 시 애니메이션 일시 정지 (절전 모드)", isOn: $pauseOnBattery)
                        .font(.system(size: 11.5))
                        .onChange(of: pauseOnBattery) { _ in
                            appState.handlePowerStateChanged()
                        }
                    
                    Text("전원 어댑터 연결 시에만 움직이고, 배터리 사용 시 자동으로 정적 아이콘으로 전환됩니다.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.leading, 18)
                        .padding(.bottom, 2)
                    
                    // Live Power Status Feedback
                    HStack(spacing: 5) {
                        if !PowerHelper.hasBattery {
                            Image(systemName: "desktopcomputer")
                                .foregroundColor(.secondary)
                                .font(.system(size: 9.5))
                            Text("현재 기기는 데스크탑 Mac으로 상시 전원 공급 상태입니다.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: appState.isOnBattery ? "battery.75" : "powerplug.fill")
                                .foregroundColor(appState.isOnBattery ? .orange : .green)
                                .font(.system(size: 9.5))
                            Text(appState.isOnBattery
                                 ? (pauseOnBattery ? "현재 상태: 🔋 배터리 전원 사용 중 (절전 모드로 애니메이션 정지됨)" : "현재 상태: 🔋 배터리 전원 사용 중 (애니메이션 동작 중)")
                                 : "현재 상태: 🔌 전원 어댑터 연결됨 (애니메이션 정상 동작 중)")
                                .font(.system(size: 9.5))
                                .foregroundColor(appState.isOnBattery && pauseOnBattery ? .orange : .secondary)
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.bottom, 2)
                    
                    Divider().opacity(0.4)
                    
                    Picker("애니메이션 속도", selection: $animationSpeed) {
                        ForEach(speedOptions, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: animationSpeed) { _ in
                        appState.startMenuBarAnimation()
                    }
                }
                
                Divider().opacity(0.4)
                
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                    Text("화면이 꺼지거나 잠자기 상태가 되면 애니메이션과 백그라운드 조회가 자동 정지됩니다.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 4: Optional API Keys
            VStack(alignment: .leading, spacing: 10) {
                Text("서비스 연동 설정 (선택사항)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
                ApiKeyInputRow(
                    title: "OpenAI API 키 (선택사항 - Codex)",
                    subtitle: "미입력 시 Codex CLI 및 계정 쿼터 자동 연동",
                    placeholder: "OpenAI API 키 입력...",
                    apiKey: $codexApiKey,
                    onCommit: { appState.refreshCodex() }
                )
                
                Divider().opacity(0.4)
                
                ApiKeyInputRow(
                    title: "Gemini API 키 (선택사항)",
                    subtitle: "미입력 시 Antigravity CLI 및 계정 쿼터 자동 연동",
                    placeholder: "Gemini API 키 입력...",
                    apiKey: $geminiApiKey,
                    onCommit: { appState.refreshGemini() }
                )
                
                Divider().opacity(0.4)
                
                ApiKeyInputRow(
                    title: "Claude API 키 (선택사항)",
                    subtitle: "미입력 시 로컬 Claude Code 로그인 계정 자동 감지",
                    placeholder: "Claude API 키 입력...",
                    apiKey: $claudeApiKey,
                    onCommit: { appState.refreshClaude() }
                )
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 5: General Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("일반 및 알림")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Toggle("컴퓨터 켤 때 자동 실행 (Launch at Login)", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        LaunchAtLoginHelper.isEnabled = newValue
                    }
                ))
                .font(.system(size: 11.5, weight: .medium))
                
                Text("Mac 부팅 및 로그인 시 Catpacity가 메뉴바에 자동으로 상주합니다.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.leading, 18)
                    .padding(.bottom, 2)
                
                Divider().opacity(0.4)
                
                Picker("자동 새로고침 주기", selection: $refreshInterval) {
                    ForEach(refreshOptions, id: \.0) { item in
                        Text(item.1).tag(item.0)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: refreshInterval) { _ in
                    appState.startPeriodicRefresh()
                }
                
                Toggle("잔여량 20% 이하 시 고양이 지침 알림 받기", isOn: $notifyHighUsage)
                    .font(.system(size: 11))
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
                }
                .padding(.trailing, 2)
            }
            
            // Footer (Pinned)
            VStack(spacing: 8) {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Catpacity v\(UpdateCheckerService.shared.currentVersion)")
                            .font(.system(size: 11, weight: .semibold))
                        if let msg = appState.updateStatusMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.system(size: 9.5))
                                .foregroundColor(appState.updateAvailable ? .blue : .secondary)
                        } else {
                            Text("Codex • Gemini • Claude")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if appState.updateAvailable {
                        if appState.isSelfUpdating {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                Text(appState.selfUpdateProgressText.isEmpty ? "업데이트 중..." : appState.selfUpdateProgressText)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button("지금 업데이트") {
                                appState.startSelfUpdate()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .font(.system(size: 11, weight: .bold))
                        }
                    } else {
                        Button(action: {
                            appState.checkForUpdates(manual: true)
                        }) {
                            if appState.isCheckingUpdate {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Text("업데이트 확인")
                                    .font(.system(size: 11))
                            }
                        }
                        .disabled(appState.isCheckingUpdate)
                    }
                    
                    Button("새로고침") {
                        appState.refreshAll()
                    }
                    .font(.system(size: 11))
                }
            }
        }
        .padding(16)
        .frame(width: 460, height: 600)
        .onDisappear {
            appState.updateMenuBar()
        }
    }
}

struct ApiKeyInputRow: View {
    let title: String
    let subtitle: String
    let placeholder: String
    @Binding var apiKey: String
    var onCommit: () -> Void
    
    @State private var isVisible: Bool = false
    
    private var maskedPreview: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 10 {
            let prefix = trimmed.prefix(3)
            return "\(prefix)••• (\(trimmed.count)자)"
        }
        let prefix = trimmed.prefix(6)
        let suffix = trimmed.suffix(4)
        return "\(prefix)••••••••\(suffix) (\(trimmed.count)자)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(maskedPreview)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 6) {
                Group {
                    if isVisible {
                        TextField(placeholder, text: $apiKey)
                    } else {
                        SecureField(placeholder, text: $apiKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .onChange(of: apiKey) { _ in
                    onCommit()
                }
                
                // 보기 / 가리기 토글 버튼
                Button(action: {
                    isVisible.toggle()
                }) {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .help(isVisible ? "키 숨기기" : "키 보기")
                
                // 클립보드 붙여넣기 원클릭 버튼
                Button(action: {
                    if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
                        apiKey = clip
                        onCommit()
                    }
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .help("클립보드에서 붙여넣기")
                
                // 키 초기화 / 삭제 버튼
                if !apiKey.isEmpty {
                    Button(action: {
                        apiKey = ""
                        onCommit()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .help("키 삭제")
                }
            }
            
            Text(subtitle)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
        }
    }
}

