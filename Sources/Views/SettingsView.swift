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
    
    // API Keys
    @AppStorage("catpacity_gemini_api_key") private var geminiApiKey: String = ""
    @AppStorage("catpacity_claude_api_key") private var claudeApiKey: String = ""
    
    // General
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
            
            // Section 1: Menu Bar Display Settings (Checkboxes)
            VStack(alignment: .leading, spacing: 8) {
                Text("상단 메뉴바 표시 항목 (최대 3줄)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Text("표시할 AI 서비스를 체크하세요 (체크한 개수에 따라 1~3줄로 자동 표시):")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Toggle("OpenAI Codex", isOn: $showCodex)
                        .font(.system(size: 11.5, weight: .medium))
                        .onChange(of: showCodex) { _ in appState?.updateMenuBar() }
                    
                    Toggle("Google Gemini", isOn: $showGemini)
                        .font(.system(size: 11.5, weight: .medium))
                        .onChange(of: showGemini) { _ in appState?.updateMenuBar() }
                    
                    Toggle("Anthropic Claude", isOn: $showClaude)
                        .font(.system(size: 11.5, weight: .medium))
                        .onChange(of: showClaude) { _ in appState?.updateMenuBar() }
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
            
            // Section 2: Optional API Keys
            VStack(alignment: .leading, spacing: 8) {
                Text("서비스 연동 설정 (선택사항)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gemini API 키 (선택사항 - AI Studio)")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    SecureField("미입력 시 \"Gemini\" 기본 롤링 리셋 자동 적용", text: $geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onChange(of: geminiApiKey) { _ in appState?.refreshGemini() }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude API 키 (선택사항 - Anthropic API)")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    SecureField("미입력 시 로컬 Claude Code / Pro 플랜 자동 연동", text: $claudeApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onChange(of: claudeApiKey) { _ in appState?.refreshClaude() }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 3: General Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("일반 및 알림")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
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
            
            Spacer()
            
            HStack {
                Text("Catpacity v1.1.0 • Codex + Gemini + Claude")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("지금 전체 새로고침") {
                    appState?.refreshAll()
                }
                .font(.system(size: 11))
            }
        }
        .padding(16)
        .frame(width: 400, height: 490)
        .onDisappear {
            appState?.updateMenuBar()
        }
    }
}
