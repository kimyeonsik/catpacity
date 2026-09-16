import Foundation

public struct TimeFormatter {
    public static func formatCountdown(until targetDate: Date?) -> String {
        guard let targetDate = targetDate else { return "리셋 정보 없음" }
        let now = Date()
        let interval = targetDate.timeIntervalSince(now)
        
        if interval <= 0 {
            return "곧 리셋됩니다"
        }
        
        let seconds = Int(interval)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        
        if days > 0 {
            return "\(days)일 \(hours)시간 남음"
        } else if hours > 0 {
            return "\(hours)시간 \(minutes)분 남음"
        } else if minutes > 0 {
            return "\(minutes)분 남음"
        } else {
            return "\(seconds)초 남음"
        }
    }
    
    public static func formatShortReset(until targetDate: Date?) -> String {
        guard let targetDate = targetDate else { return "" }
        let now = Date()
        let interval = targetDate.timeIntervalSince(now)
        if interval <= 0 { return "곧 리셋" }
        
        let seconds = Int(interval)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        
        if days > 0 {
            return "\(days)일 남음"
        } else if hours > 0 {
            return "\(hours)시간 남음"
        } else if minutes > 0 {
            return "\(minutes)분 남음"
        } else {
            return "\(seconds)초 남음"
        }
    }
    
    public static func formatExactTime(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "M월 d일 a h:mm"
        return df.string(from: date)
    }
    
    public static func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "방금 전"
        } else if interval < 3600 {
            return "\(Int(interval / 60))분 전"
        } else {
            return "\(Int(interval / 3600))시간 전"
        }
    }
}
