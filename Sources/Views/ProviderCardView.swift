import SwiftUI

public struct ProviderCardAction {
    public let title: String
    public let subtitle: String?
    public let buttonTitle: String
    public let icon: String?
    public let tintColor: Color
    public let isLoading: Bool
    public let action: () -> Void
    
    public init(
        title: String,
        subtitle: String? = nil,
        buttonTitle: String,
        icon: String? = nil,
        tintColor: Color = .purple,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.icon = icon
        self.tintColor = tintColor
        self.isLoading = isLoading
        self.action = action
    }
}

public struct ProviderCardView: View {
    public let iconName: String
    public let providerTitle: String
    public let planName: String
    public let usedPercent: Double
    public let resetsAt: Date?
    public let isConnected: Bool
    public let errorMessage: String?
    public let extraDetails: [String]
    public let resetLabel: String
    public let badgeText: String?
    public let badgeColor: Color
    public let customAction: ProviderCardAction?
    public let usageMode: ProviderUsageMode?
    public let onRefresh: () -> Void
    
    public init(
        iconName: String,
        providerTitle: String,
        planName: String,
        usedPercent: Double,
        resetsAt: Date?,
        isConnected: Bool,
        errorMessage: String?,
        extraDetails: [String],
        resetLabel: String = "리셋:",
        badgeText: String? = nil,
        badgeColor: Color = .purple,
        customAction: ProviderCardAction? = nil,
        usageMode: ProviderUsageMode? = nil,
        onRefresh: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.providerTitle = providerTitle
        self.planName = planName
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.isConnected = isConnected
        self.errorMessage = errorMessage
        self.extraDetails = extraDetails
        self.resetLabel = resetLabel
        self.badgeText = badgeText
        self.badgeColor = badgeColor
        self.customAction = customAction
        self.usageMode = usageMode
        self.onRefresh = onRefresh
    }
    
    public var remainingPercent: Double {
        if let mode = usageMode {
            switch mode {
            case .subscriptionActive(let rem, _, _):
                return rem
            case .subscriptionExhausted:
                return 0.0
            case .payAsYouGoOnly(let cost, let budget, _, _):
                let spentRatio = cost / max(1.0, budget)
                return max(0.0, 100.0 - spentRatio * 100.0)
            case .disconnected:
                return 0.0
            }
        }
        return max(0.0, 100.0 - usedPercent)
    }
    
    public var effectiveBadgeText: String? {
        if let text = badgeText, !text.isEmpty {
            return text
        }
        guard let mode = usageMode else { return nil }
        switch mode {
        case .subscriptionActive:
            // 평소 구독 정상 상태일 때는 API 키 관련 배지나 문구를 일절 노출하지 않음
            return nil
        case .subscriptionExhausted(_, let hasApiKey, _, _):
            return hasApiKey ? "⚡️ API 과금" : "한도 소진"
        case .payAsYouGoOnly:
            return "종량제 API"
        case .disconnected:
            return nil
        }
    }
    
    public var effectiveBadgeColor: Color {
        guard let mode = usageMode else { return badgeColor }
        switch mode {
        case .subscriptionActive:
            return badgeColor
        case .subscriptionExhausted(_, let hasApiKey, _, _):
            return hasApiKey ? Color.orange : Color.red
        case .payAsYouGoOnly:
            return Color.purple
        case .disconnected:
            return badgeColor
        }
    }
    
    public var gaugeRatio: Double {
        if let mode = usageMode {
            switch mode {
            case .subscriptionActive(let rem, _, _):
                return max(0.0, min(100.0, rem)) / 100.0
            case .subscriptionExhausted(_, let hasApiKey, let cost, _):
                if hasApiKey {
                    let currentCost = cost ?? 0.0
                    let budget = 50.0
                    let ratio = currentCost / budget
                    return max(0.03, min(1.0, ratio))
                } else {
                    return 0.0
                }
            case .payAsYouGoOnly(let cost, let budget, _, _):
                let spentRatio = cost / max(1.0, budget)
                return max(0.03, min(1.0, spentRatio))
            case .disconnected:
                return 0.0
            }
        }
        return max(0.0, min(1.0, remainingPercent / 100.0))
    }
    
    public var progressColor: Color {
        if let mode = usageMode {
            switch mode {
            case .payAsYouGoOnly(let cost, let budget, _, _):
                let spentRatio = cost / max(1.0, budget)
                if spentRatio < 0.5 { return .blue }
                if spentRatio < 0.8 { return .orange }
                return .red
            case .subscriptionExhausted(_, let hasApiKey, let cost, _):
                if hasApiKey {
                    let spentRatio = (cost ?? 0.0) / 50.0
                    if spentRatio < 0.5 { return .orange }
                    return .red
                } else {
                    return .red
                }
            case .subscriptionActive:
                break
            case .disconnected:
                return .secondary
            }
        }
        switch remainingPercent {
        case 60...:   return .green
        case 30..<60: return .yellow
        case 15..<30: return .orange
        default:      return .red
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Card Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text(providerTitle)
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    if let badge = effectiveBadgeText {
                        Text(badge)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(effectiveBadgeColor)
                            )
                    }
                    
                    Circle()
                        .fill(isConnected ? Color.green : (errorMessage?.contains("확인 중") == true ? Color.yellow : Color.red.opacity(0.8)))
                        .frame(width: 6, height: 6)
                    
                    Text(planName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = errorMessage, !isConnected {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(error.contains("확인 중") ? .secondary : .red.opacity(0.8))
            } else {
                // Progress Bar & Remaining Percentage
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        if let mode = usageMode, case .payAsYouGoOnly(let cost, let budget, _, _) = mode {
                            Text("월 사용 금액")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "$%.2f / $%.0f", cost, budget))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(progressColor)
                            Text(String(format: "(%.1f%%)", min(100.0, cost / max(1.0, budget) * 100.0)))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else if let mode = usageMode, case .subscriptionExhausted(_, let hasApiKey, let cost, _) = mode {
                            if hasApiKey {
                                Text("전환 후 API 지출")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                let currentCost = cost ?? 0.0
                                Text(String(format: "$%.2f / $50", currentCost))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(progressColor)
                                Text(String(format: "(%.1f%%)", min(100.0, currentCost / 50.0 * 100.0)))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("구독 한도")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("0.0% 남음 (소진됨)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        } else {
                            Text("잔여량")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f", remainingPercent))% 남음")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(progressColor)
                            Text("(사용: \(String(format: "%.0f", usedPercent))%)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Capacity Gauge Bar (Fills according to remaining capacity or expense ratio)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 7)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [progressColor.opacity(0.8), progressColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(gaugeRatio))), height: 7)
                        }
                    }
                    .frame(height: 7)
                }
                
                // Reset Countdown Info
                if resetsAt != nil || usageMode != nil {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(resetLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(TimeFormatter.formatCountdown(until: resetsAt))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let resetDate = resetsAt {
                            Text("(\(TimeFormatter.formatExactTime(resetDate)))")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                
                // Mode-specific and extra metadata rows
                let computedDetails: [String] = {
                    var list: [String] = []
                    if let mode = usageMode {
                        switch mode {
                        case .subscriptionActive:
                            // 평소 구독 정상 상태일 때는 API 키 관련 텍스트 노출 안 함
                            break
                        case .subscriptionExhausted(_, let hasApiKey, let cost, let tokens):
                            if hasApiKey {
                                list.append("⚡️ 현재 상태: API 키 호출 사용 중")
                                if let c = cost {
                                    list.append("💵 소모 금액: $\(String(format: "%.2f", c))")
                                }
                                if let t = tokens {
                                    list.append("🔢 소모 토큰: \(t.formatted()) tokens")
                                }
                            }
                        case .payAsYouGoOnly(let cost, let budget, let tokens, _):
                            list.append("💵 이번 달 청구: $\(String(format: "%.2f", cost)) (잔여 예산: $\(String(format: "%.2f", max(0.0, budget - cost))))")
                            if let t = tokens {
                                list.append("🔢 소모 토큰: \(t.formatted()) tokens")
                            }
                        case .disconnected:
                            break
                        }
                    }
                    list.append(contentsOf: extraDetails)
                    return list
                }()
                
                if !computedDetails.isEmpty {
                    Divider()
                        .opacity(0.4)
                    
                    ForEach(computedDetails, id: \.self) { detail in
                        HStack(spacing: 4) {
                            Text("•")
                                .foregroundColor(.secondary)
                                .font(.system(size: 9))
                            Text(detail)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Custom Action Banner (e.g. Codex Reset Ticket)
                if let action = customAction {
                    Divider()
                        .opacity(0.4)
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.primary)
                            if let subtitle = action.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: action.action) {
                            HStack(spacing: 4) {
                                if action.isLoading {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else if let icon = action.icon {
                                    Image(systemName: icon)
                                        .font(.system(size: 9.5))
                                }
                                Text(action.buttonTitle)
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(action.tintColor)
                        .controlSize(.mini)
                        .disabled(action.isLoading)
                    }
                    .padding(8)
                    .background(action.tintColor.opacity(0.08))
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
