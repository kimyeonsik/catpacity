import SwiftUI

public struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @AppStorage("catpacity_gemini_api_key") private var geminiApiKey: String = ""
    @AppStorage("catpacity_gemini_plan_type") private var geminiPlanType: String = "Gemini Advanced"
    @AppStorage("catpacity_gemini_manual_used_percent") private var geminiManualUsed: Double = 35.0
    @AppStorage("catpacity_refresh_interval") private var refreshInterval: Int = 300 // 5 mins
    @AppStorage("catpacity_menubar_mode") private var menuBarMode: String = "cat_only"
    @AppStorage("catpacity_notify_on_high_usage") private var notifyHighUsage: Bool = true
    
    let planOptions = [
        "Gemini Advanced (Google One 2TB)",
        "Gemini API (Google AI Studio)",
        "Gemini 1.5 Flash / Pro",
        "Google Antigravity / Code Assist"
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
                
                Picker("플랜 선택", selection: $geminiPlanType) {
                    ForEach(planOptions, id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gemini API 키 (선택사항 - AI Studio 사용자)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    SecureField("AI Studio API Key 입력 (미입력 시 플랜 기본값 사용)", text: $geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
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
                
                Picker("자동 새로고침 주기", selection: $refreshInterval) {
                    ForEach(refreshOptions, id: \.0) { item in
                        Text(item.1).tag(item.0)
                    }
                }
                .pickerStyle(.menu)
                
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
        .frame(width: 360, height: 420)
    }
}
