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
