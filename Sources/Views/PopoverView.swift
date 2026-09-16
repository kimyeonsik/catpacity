import SwiftUI

public struct PopoverView: View {
    @ObservedObject var appState: AppState
    @State private var showingSettings = false
    @State private var previewMode = false
    @State private var previewPercent: Double = 67.0
    
    public var body: some View {
        let activeRemaining = previewMode ? previewPercent : appState.overallUsage.minRemainingPercent
        let activeStage = CatStage.from(remainingPercent: activeRemaining)
        
        VStack(spacing: 12) {
            // Header: Dynamic Retro Animated Pixel Cat Graphic + Quote
            CatIllustrationView(
                stage: activeStage,
                remainingPercent: activeRemaining,
                animFrame: appState.currentAnimFrame
            )
            
            // Cards Container
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // Codex Card
                    ProviderCardView(
                        iconName: "cpu",
                        providerTitle: "OpenAI Codex",
                        planName: appState.overallUsage.codex.planType,
                        usedPercent: appState.overallUsage.codex.usedPercent,
                        resetsAt: appState.overallUsage.codex.resetsAt,
                        isConnected: appState.overallUsage.codex.isConnected,
                        errorMessage: appState.overallUsage.codex.errorMessage,
                        extraDetails: codexDetails,
                        onRefresh: {
                            appState.refreshCodex()
                        }
                    )
                    
                    // Gemini Card
                    ProviderCardView(
                        iconName: "sparkles",
                        providerTitle: "Google Gemini",
                        planName: appState.overallUsage.gemini.planName,
                        usedPercent: appState.overallUsage.gemini.usedPercent,
                        resetsAt: appState.overallUsage.gemini.resetsAt,
                        isConnected: appState.overallUsage.gemini.isConnected,
                        errorMessage: appState.overallUsage.gemini.errorMessage,
                        extraDetails: geminiDetails,
                        onRefresh: {
                            appState.refreshGemini()
                        },
                        onConfigure: {
                            showingSettings = true
                        }
                    )
                    
                    // Interactive Cat Simulator (Toggle)
                    if previewMode {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("고양이 변신 테스트 슬라이더 🐾")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.purple)
                                Spacer()
                                Text("잔여 \(Int(previewPercent))%")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Slider(value: $previewPercent, in: 0...100, step: 1)
                                .accentColor(.purple)
                        }
                        .padding(10)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: 280)
            
            Divider()
            
            // Footer Controls
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text(TimeFormatter.formatRelativeTime(appState.lastSyncTime))
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        previewMode.toggle()
                    }
                }) {
                    Image(systemName: previewMode ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(previewMode ? .purple : .secondary)
                }
                .buttonStyle(.plain)
                .help(previewMode ? "시뮬레이션 닫기" : "고양이 늘어짐 단계 미리보기")
                
                Button(action: {
                    appState.refreshAll()
                }) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("지금 새로고침")
                
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("설정")
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("앱 종료")
            }
            .padding(.horizontal, 2)
        }
        .padding(14)
        .frame(width: 320)
        .sheet(isPresented: $showingSettings) {
            SettingsView(appState: appState)
        }
    }
    
    private var codexDetails: [String] {
        var items: [String] = []
        let codex = appState.overallUsage.codex
        if let credits = codex.creditsBalance, credits != "0" {
            items.append("잔여 크레딧: \(credits)")
        }
        for sub in codex.submodels {
            let name = sub.limitName ?? sub.limitId
            items.append("\(name): \(Int(sub.remainingPercent))% 남음")
        }
        return items
    }
    
    private var geminiDetails: [String] {
        var items: [String] = []
        let gemini = appState.overallUsage.gemini
        if let remTokens = gemini.remainingTokens, let limTokens = gemini.limitTokens {
            items.append("잔여 토큰: \(remTokens.formatted()) / \(limTokens.formatted()) TPM")
        }
        if let remReq = gemini.usedRequests, let limReq = gemini.limitRequests {
            items.append("사용 요청: \(remReq) / \(limReq) RPM")
        }
        return items
    }
}
