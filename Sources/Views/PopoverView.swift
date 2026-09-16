import SwiftUI

public struct PopoverView: View {
    @ObservedObject var appState: AppState
    @State private var showingSettings = false
    
    public var body: some View {
        let activeRemaining = appState.overallUsage.minRemainingPercent
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
                    
                    // Claude Card
                    ProviderCardView(
                        iconName: "brain.head.profile",
                        providerTitle: "Anthropic Claude",
                        planName: appState.overallUsage.claude.planName,
                        usedPercent: appState.overallUsage.claude.usedPercent,
                        resetsAt: appState.overallUsage.claude.resetsAt,
                        isConnected: appState.overallUsage.claude.isConnected,
                        errorMessage: appState.overallUsage.claude.errorMessage,
                        extraDetails: claudeDetails,
                        onRefresh: {
                            appState.refreshClaude()
                        },
                        onConfigure: {
                            showingSettings = true
                        }
                    )
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: 350)
            
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
    
    private var claudeDetails: [String] {
        var items: [String] = []
        let claude = appState.overallUsage.claude
        if !claude.isConnected {
            items.append("로그인 또는 설정(⚙️)에서 API 키 연동")
        } else if claude.planName.contains("Max") {
            items.append("Claude Max 플랜 (우선 한도)")
        } else if claude.planName.contains("Pro") {
            items.append("Claude Pro 5시간 롤링 리셋")
        } else if claude.planName.contains("API") {
            items.append("Anthropic API 키 연동")
        }
        return items
    }
}
