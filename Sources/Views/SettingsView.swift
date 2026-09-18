import SwiftUI

public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    public var appState: AppState? = nil
    
    // Menu Bar Display Customization
    @AppStorage("catpacity_show_codex") private var showCodex: Bool = true
    @AppStorage("catpacity_show_gemini") private var showGemini: Bool = true
    @AppStorage("catpacity_show_claude") private var showClaude: Bool = true
    @AppStorage("catpacity_show_percent") private var showPercent: Bool = true
    @AppStorage("catpacity_show_reset_time") private var showResetTime: Bool = true
    
    // Cat Status Target Customization
    @AppStorage("catpacity_cat_status_target") private var catStatusTarget: String = "min"
    
    // API Keys
    @AppStorage("catpacity_gemini_api_key") private var geminiApiKey: String = ""
    @AppStorage("catpacity_claude_api_key") private var claudeApiKey: String = ""
    
    // General
    @State private var launchAtLogin: Bool = LaunchAtLoginHelper.isEnabled
    @AppStorage("catpacity_refresh_interval") private var refreshInterval: Int = 300 // 5 mins
    @AppStorage("catpacity_notify_on_high_usage") private var notifyHighUsage: Bool = true
    
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
                    appState?.updateMenuBar()
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
                                    appState?.updateMenuBar()
                                    appState?.objectWillChange.send()
                                }
                            
                            Toggle("Google Gemini", isOn: $showGemini)
                                .font(.system(size: 11.5, weight: .medium))
                                .onChange(of: showGemini) { _ in
                                    appState?.updateMenuBar()
                                    appState?.objectWillChange.send()
                                }
                            
                            Toggle("Anthropic Claude", isOn: $showClaude)
                                .font(.system(size: 11.5, weight: .medium))
                                .onChange(of: showClaude) { _ in
                                    appState?.updateMenuBar()
                                    appState?.objectWillChange.send()
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
                        .onChange(of: showPercent) { _ in appState?.updateMenuBar() }
                    
                    Toggle("리셋 남은 시간 표시", isOn: $showResetTime)
                        .font(.system(size: 11.5))
                        .onChange(of: showResetTime) { _ in appState?.updateMenuBar() }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 2: Cat Status Target AI Service
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("고양이 표정 / 상태 기준 AI")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Spacer()
                    if let label = appState?.activeTargetLabel, !label.isEmpty {
                        Text("현재: \(label)")
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
                    appState?.updateLineCache()
                    appState?.updateMenuBar()
                    appState?.objectWillChange.send()
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 3: Optional API Keys
            VStack(alignment: .leading, spacing: 8) {
                Text("서비스 연동 설정 (선택사항)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gemini API 키 (선택사항 - AI Studio)")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    SecureField("미입력 시 Antigravity CLI 및 계정 쿼터 자동 연동", text: $geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onChange(of: geminiApiKey) { _ in appState?.refreshGemini() }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude API 키 (선택사항 - Anthropic API)")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    SecureField("미입력 시 로컬 Claude Code 로그인 계정 자동 감지", text: $claudeApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onChange(of: claudeApiKey) { _ in appState?.refreshClaude() }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 4: General Settings
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
                    appState?.startPeriodicRefresh()
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
                        Text("Catpacity v1.3.1")
                            .font(.system(size: 11, weight: .semibold))
                        if let msg = appState?.updateStatusMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.system(size: 9.5))
                                .foregroundColor(appState?.updateAvailable == true ? .blue : .secondary)
                        } else {
                            Text("Codex • Gemini • Claude")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if appState?.updateAvailable == true {
                        if appState?.isSelfUpdating == true {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                Text(appState?.selfUpdateProgressText ?? "업데이트 중...")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button("지금 업데이트") {
                                appState?.startSelfUpdate()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .font(.system(size: 11, weight: .bold))
                        }
                    } else {
                        Button(action: {
                            appState?.checkForUpdates(manual: true)
                        }) {
                            if appState?.isCheckingUpdate == true {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Text("업데이트 확인")
                                    .font(.system(size: 11))
                            }
                        }
                        .disabled(appState?.isCheckingUpdate == true)
                    }
                    
                    Button("새로고침") {
                        appState?.refreshAll()
                    }
                    .font(.system(size: 11))
                }
            }
        }
        .padding(16)
        .frame(width: 440, height: 580)
        .onDisappear {
            appState?.updateMenuBar()
        }
    }
}
