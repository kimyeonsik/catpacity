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
        self.onRefresh = onRefresh
    }
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public var progressColor: Color {
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
                    if let badge = badgeText {
                        Text(badge)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(badgeColor)
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
                    
                    // Capacity Gauge Bar (Fills according to remaining capacity)
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
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(remainingPercent / 100.0))), height: 7)
                        }
                    }
                    .frame(height: 7)
                }
                
                // Reset Countdown Info
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
                
                // Extra metadata rows (credits, models, etc.)
                if !extraDetails.isEmpty {
                    Divider()
                        .opacity(0.4)
                    
                    ForEach(extraDetails, id: \.self) { detail in
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
