import SwiftUI

private struct CardsContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum ResetAlertItem: Identifiable {
    case confirm
    case result(success: Bool, message: String)
    
    var id: String {
        switch self {
        case .confirm:
            return "confirm"
        case .result(let s, let m):
            return "\(s)_\(m)"
        }
    }
}

public struct PopoverView: View {
    @ObservedObject var appState: AppState
    @State private var showingSettings = false
    @State private var measuredCardsHeight: CGFloat = 0
    @State private var resetAlert: ResetAlertItem? = nil
    @State private var isConsumingResetCredit = false
    
    @AppStorage("catpacity_show_codex") private var showCodex: Bool = true
    @AppStorage("catpacity_show_gemini") private var showGemini: Bool = true
    @AppStorage("catpacity_show_claude") private var showClaude: Bool = true
    
    private var maxAllowedCardsHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 850
        // Leave room for cat header (~120pt), footer (~50pt), margins (~60pt)
        return max(350, screenHeight - 240)
    }
    
    public var body: some View {
        let activeRemaining = appState.activeRemainingPercent
        let activeStage = appState.activeCatStage
        
        VStack(spacing: 12) {
            // Header: Dynamic Retro Animated Pixel Cat Graphic + Quote
            CatIllustrationView(
                stage: activeStage,
                breed: appState.selectedBreed,
                remainingPercent: activeRemaining,
                animFrame: appState.currentAnimFrame,
                targetLabel: "기준: \(appState.activeTargetLabel)"
            )

            
            // Update Notification Banner (if newer version available on GitHub)
            if appState.updateAvailable {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Text("새 버전 \(appState.latestVersionTag) 출시!")
                            .font(.system(size: 11, weight: .semibold))
                        
                        Spacer()
                        
                        if appState.isSelfUpdating {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Button("지금 업데이트") {
                                appState.startSelfUpdate()
                            }
                            .font(.system(size: 10, weight: .bold))
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                        }
                    }
                    
                    if appState.isSelfUpdating {
                        HStack {
                            Text(appState.selfUpdateProgressText)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    if let err = appState.selfUpdateError {
                        HStack {
                            Text(err)
                                .font(.system(size: 9.5))
                                .foregroundColor(.red)
                            Spacer()
                            Button("브라우저에서 받기") {
                                let urlStr = appState.latestReleaseUrl.isEmpty ? "https://github.com/kimyeonsik/catpacity/releases/latest" : appState.latestReleaseUrl
                                if let url = URL(string: urlStr) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .font(.system(size: 9.5))
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(8)
            }
            
            // Cards Container: Dynamically expands to content; only scrolls if screen height limit is reached
            ScrollView(.vertical, showsIndicators: measuredCardsHeight > maxAllowedCardsHeight) {
                VStack(spacing: 10) {
                    if showCodex {
                        // Codex Card
                        let codex = appState.overallUsage.codex
                        let resetAction: ProviderCardAction? = codex.isConnected && codex.resetCreditsAvailableCount > 0 ? ProviderCardAction(
                            title: "🎟️ 리셋권 \(codex.resetCreditsAvailableCount)장 보유 중",
                            subtitle: "사용 즉시 한도가 100%로 복구됩니다",
                            buttonTitle: isConsumingResetCredit ? "리셋 중..." : "지금 리셋",
                            icon: "arrow.counterclockwise.circle.fill",
                            tintColor: .purple,
                            isLoading: isConsumingResetCredit,
                            action: {
                                resetAlert = .confirm
                            }
                        ) : nil
                        
                        ProviderCardView(
                            iconName: "cpu",
                            providerTitle: "OpenAI Codex",
                            planName: codex.planType,
                            usedPercent: codex.usedPercent,
                            resetsAt: codex.resetsAt,
                            isConnected: codex.isConnected,
                            errorMessage: codex.errorMessage,
                            extraDetails: codexDetails,
                            badgeText: codex.isConnected && codex.resetCreditsAvailableCount > 0 ? "🎟️ 리셋권 \(codex.resetCreditsAvailableCount)장" : nil,
                            badgeColor: .purple,
                            customAction: resetAction,
                            onRefresh: {
                                appState.refreshCodex()
                            }
                        )
                    }
                    
                    if showGemini {
                        // Gemini Card
                        let gemini = appState.overallUsage.gemini
                        let geminiResetLabel: String = {
                            if gemini.weeklyRemainingPercent != nil {
                                if gemini.resetsAt != gemini.weeklyResetsAt {
                                    return "5시간 리셋:"
                                } else {
                                    return "주간 리셋:"
                                }
                            }
                            return "리셋:"
                        }()
                        
                        ProviderCardView(
                            iconName: "sparkles",
                            providerTitle: "Google Gemini",
                            planName: gemini.planName,
                            usedPercent: gemini.usedPercent,
                            resetsAt: gemini.resetsAt,
                            isConnected: gemini.isConnected,
                            errorMessage: gemini.errorMessage,
                            extraDetails: geminiDetails,
                            resetLabel: geminiResetLabel,
                            onRefresh: {
                                appState.refreshGemini()
                            }
                        )
                    }
                    
                    if showClaude {
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
                            }
                        )
                    }
                    
                    if !showCodex && !showGemini && !showClaude {
                        VStack(spacing: 8) {
                            Image(systemName: "slash.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("표시할 AI 서비스가 없습니다.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("하단 ⚙️ 설정에서 AI 서비스를 선택해주세요.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 2)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: CardsContentHeightKey.self, value: geo.size.height)
                    }
                )
            }
            .frame(height: measuredCardsHeight > 0 ? min(measuredCardsHeight, maxAllowedCardsHeight) : nil)
            .onPreferenceChange(CardsContentHeightKey.self) { newHeight in
                measuredCardsHeight = newHeight
                NotificationCenter.default.post(name: NSNotification.Name("CatpacityPopoverResize"), object: nil)
            }
            
            Divider()
            
            // Footer Controls (Single unified settings button)
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
        .frame(width: 375)
        .sheet(isPresented: $showingSettings) {
            SettingsView(appState: appState)
        }
        .alert(item: $resetAlert) { item in
            switch item {
            case .confirm:
                return Alert(
                    title: Text("🎟️ Codex 리셋권 사용"),
                    message: Text("보유 중인 리셋권을 사용하여 Codex 한도를 100%로 즉시 복구하시겠습니까?"),
                    primaryButton: .default(Text("리셋하기")) {
                        isConsumingResetCredit = true
                        CodexService.shared.consumeResetCredit { success, err in
                            isConsumingResetCredit = false
                            if success {
                                resetAlert = .result(success: true, message: "🎉 Codex 한도가 100%로 성공적으로 복구되었습니다!")
                            } else {
                                resetAlert = .result(success: false, message: "❌ 리셋 처리 실패: \(err ?? "알 수 없는 오류")")
                            }
                        }
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            case .result(let success, let message):
                return Alert(
                    title: Text(success ? "리셋 완료" : "리셋 실패"),
                    message: Text(message),
                    dismissButton: .default(Text("확인"))
                )
            }
        }
    }
    
    private var codexDetails: [String] {
        var items: [String] = []
        let codex = appState.overallUsage.codex
        if !codex.isConnected {
            if codex.isChecking || codex.errorMessage?.contains("확인 중") == true {
                items.append("Codex 연결 확인 중...")
            } else {
                items.append(codex.errorMessage ?? "Codex 미연동")
            }
        } else {
            if !codex.ordinaryUsageAllowed {
                items.append("⚠️ 이번 주기 일반 한도 소진 (리셋 대기)")
            }
            if codex.resetCreditsAvailableCount > 0 {
                let title = codex.resetCredits.first?.title ?? "한도 100% 복구"
                items.append("🎟️ 리셋권: \(codex.resetCreditsAvailableCount)장 보유 중 (\(title))")
                if let exp = codex.resetCredits.first?.expiresAt {
                    let formattedExp = TimeFormatter.formatExactTime(exp)
                    items.append("   ↳ 유효기간: \(formattedExp)까지")
                }
            } else {
                items.append("🎟️ 리셋권: 0장")
            }
            if let credits = codex.creditsBalance, credits != "0" {
                items.append("잔여 크레딧: \(credits)")
            }
            for sub in codex.submodels {
                let name = sub.limitName ?? sub.limitId
                items.append("\(name): \(Int(sub.remainingPercent))% 남음")
            }
        }
        return items
    }
    
    private var geminiDetails: [String] {
        var items: [String] = []
        let gemini = appState.overallUsage.gemini
        if !gemini.isConnected {
            if gemini.isChecking || gemini.errorMessage?.contains("확인 중") == true {
                items.append("Antigravity 쿼터 확인 중...")
            } else {
                items.append("Antigravity CLI 또는 AI Studio API 키 필요")
            }
        } else {
            if let weekly = gemini.weeklyRemainingPercent {
                items.append("주간 잔여 한도: \(Int(weekly))% 남음")
            }
            if let weeklyReset = gemini.weeklyResetsAt, gemini.resetsAt != weeklyReset {
                let countdown = TimeFormatter.formatCountdown(until: weeklyReset)
                let exact = TimeFormatter.formatExactTime(weeklyReset)
                items.append("주간 리셋: \(countdown) (\(exact))")
            }
            if let remTokens = gemini.remainingTokens, let limTokens = gemini.limitTokens {
                items.append("잔여 토큰: \(remTokens.formatted()) / \(limTokens.formatted()) TPM")
            }
            if let remReq = gemini.usedRequests, let limReq = gemini.limitRequests {
                items.append("사용 요청: \(remReq) / \(limReq) RPM")
            }
        }
        return items
    }
    
    private var claudeDetails: [String] {
        var items: [String] = []
        let claude = appState.overallUsage.claude
        if !claude.isConnected {
            if claude.isChecking || claude.errorMessage?.contains("확인 중") == true {
                items.append("Claude 로그인 확인 중...")
            } else {
                items.append("구독 해지됨 또는 미로그인 (설정에서 API 키 연동 가능)")
            }
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
