import SwiftUI

public struct ProviderCardView: View {
    public let iconName: String
    public let providerTitle: String
    public let planName: String
    public let usedPercent: Double
    public let resetsAt: Date?
    public let isConnected: Bool
    public let errorMessage: String?
    public let extraDetails: [String]
    public let onRefresh: () -> Void
    public var onConfigure: (() -> Void)? = nil
    
    public var progressColor: Color {
        switch usedPercent {
        case ..<40: return .green
        case 40..<70: return .yellow
        case 70..<90: return .orange
        default: return .red
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
                    Circle()
                        .fill(isConnected ? Color.green : Color.red.opacity(0.8))
                        .frame(width: 6, height: 6)
                    
                    Text(planName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let configure = onConfigure {
                        Button(action: configure) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("설정")
                    }
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
            } else {
                // Progress Bar & Percentage
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("사용량")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", usedPercent))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(progressColor)
                        Text("(\(String(format: "%.0f", max(0, 100 - usedPercent)))% 남음)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    // Custom rounded progress bar
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
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(usedPercent / 100.0))), height: 7)
                        }
                    }
                    .frame(height: 7)
                }
                
                // Reset Countdown Info
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text("리셋:")
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
