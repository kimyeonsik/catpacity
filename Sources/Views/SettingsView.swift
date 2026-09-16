import SwiftUI

public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    public var appState: AppState? = nil
    
    @AppStorage("catpacity_gemini_api_key") private var geminiApiKey: String = ""
    @AppStorage("catpacity_gemini_plan_type") private var geminiPlanType: String = "Google AI Pro"
    @AppStorage("catpacity_gemini_manual_used_percent") private var geminiManualUsed: Double = 35.0
    @AppStorage("catpacity_refresh_interval") private var refreshInterval: Int = 300 // 5 mins
    @AppStorage("catpacity_menubar_mode") private var menuBarMode: String = "cat_only"
    @AppStorage("catpacity_notify_on_high_usage") private var notifyHighUsage: Bool = true
    
    @State private var selectedPlanOption: String = "Google AI Pro"
    @State private var customPlanText: String = ""
    
    let planOptions = [
        "Google AI Pro",
        "Google One AI 프리미엄",
        "Google AI 요금제 (Gemini Pro)",
        "Gemini Advanced (Google One 2TB)",
        "Google AI Studio (API 키 연동)",
        "Google Workspace Gemini",
        "Google Antigravity / Code Assist",
        "직접 입력..."
    ]
    
    let refreshOptions = [
        (60, "1분마다"),
        (300, "5분마다 (권장)"),
        (900, "15분마다"),
        (1800, "30분마다")
    ]
    
    let menuBarModes = [
        ("cat_only", "고양이 아이콘만"),
        ("cat_percent", "고양이 + 잔여량 (%)"),
        ("cat_countdown", "고양이 + 리셋 남은 시간")
    ]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("설정 ⚙️")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("완료") {
                    appState?.refreshGemini()
                    appState?.updateMenuBar()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            Divider()
            
            // Section 1: Gemini Setup
            VStack(alignment: .leading, spacing: 8) {
                Text("Gemini 요금제 설정")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Picker("플랜 선택", selection: $selectedPlanOption) {
                    ForEach(planOptions, id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPlanOption) { newVal in
                    if newVal == "직접 입력..." {
                        if customPlanText.isEmpty {
                            customPlanText = "Google AI Pro"
                        }
                        geminiPlanType = customPlanText
                    } else {
                        geminiPlanType = newVal
                    }
                    appState?.refreshGemini()
                }
                
                if selectedPlanOption == "직접 입력..." {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("플랜 이름 직접 입력:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("예: Google AI Pro, Google One AI 등", text: $customPlanText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .onChange(of: customPlanText) { newVal in
                                geminiPlanType = newVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Google AI Pro" : newVal
                                appState?.refreshGemini()
                            }
                    }
                }
                
                Text("💡 Google One 월 구독자(Gemini 1.5 Pro)는 'Google AI Pro' 또는 'Google One AI 프리미엄'을 선택하시면 됩니다.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gemini API 키 (선택사항 - AI Studio 사용자)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    SecureField("AI Studio API Key 입력 (미입력 시 플랜 기본값 사용)", text: $geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onChange(of: geminiApiKey) { _ in
                            appState?.refreshGemini()
                        }
                }
                
                if geminiApiKey.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Gemini 잔여량 조절 (시뮬레이션)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("잔여 \(Int(100.0 - geminiManualUsed))% (사용 \(Int(geminiManualUsed))%)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Slider(value: $geminiManualUsed, in: 0...100, step: 1)
                            .onChange(of: geminiManualUsed) { _ in
                                appState?.refreshGemini()
                            }
                    }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Section 2: General & Menu Bar
            VStack(alignment: .leading, spacing: 8) {
                Text("상단 메뉴바 및 알림")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.accentColor)
                
                Picker("상단 표시 형식", selection: $menuBarMode) {
                    ForEach(menuBarModes, id: \.0) { item in
                        Text(item.1).tag(item.0)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: menuBarMode) { _ in
                    appState?.updateMenuBar()
                }
                
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
                Text("Catpacity v1.0 • Cat + Capacity")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Codex 즉시 재연결") {
                    CodexService.shared.fetchUsage { _ in }
                }
                .font(.system(size: 11))
            }
        }
        .padding(16)
        .frame(width: 360, height: 470)
        .onAppear {
            if planOptions.dropLast().contains(geminiPlanType) {
                selectedPlanOption = geminiPlanType
            } else {
                selectedPlanOption = "직접 입력..."
                customPlanText = geminiPlanType
            }
        }
        .onDisappear {
            appState?.refreshGemini()
            appState?.updateMenuBar()
        }
    }
}
