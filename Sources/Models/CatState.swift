import SwiftUI

public enum CatStage: Int, CaseIterable, Comparable {
    case energetic = 1  // 80% - 100% remaining (0% - 20% used)
    case content = 2    // 50% - 79% remaining (21% - 50% used)
    case tired = 3      // 25% - 49% remaining (51% - 75% used)
    case melting = 4    // 10% - 24% remaining (76% - 90% used)
    case liquid = 5     // 0% - 9% remaining (91% - 100% used)
    
    public static func < (lhs: CatStage, rhs: CatStage) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public static func from(remainingPercent: Double) -> CatStage {
        switch remainingPercent {
        case 80.0...:
            return .energetic
        case 50.0..<80.0:
            return .content
        case 25.0..<50.0:
            return .tired
        case 10.0..<25.0:
            return .melting
        default:
            return .liquid
        }
    }
    
    public static func from(usedPercent: Double) -> CatStage {
        let remaining = max(0.0, 100.0 - usedPercent)
        return from(remainingPercent: remaining)
    }
    
    public var title: String {
        switch self {
        case .energetic: return "쌩쌩한 고양이"
        case .content:   return "느긋한 식빵냥"
        case .tired:     return "슬슬 지친 고양이"
        case .melting:   return "축~~ 늘어진 고양이"
        case .liquid:    return "완전 방전 액체 고양이"
        }
    }
    
    public var emoji: String {
        switch self {
        case .energetic: return "😺"
        case .content:   return "😸"
        case .tired:     return "😿"
        case .melting:   return "🙀"
        case .liquid:    return "🫠"
        }
    }
    
    public var quote: String {
        switch self {
        case .energetic:
            return "잔여량 넉넉해요! 기운차게 코딩하세요 ⚡️"
        case .content:
            return "토큰 여유 있어요. 느긋하게 작업 중냥 ☕️"
        case .tired:
            return "잔여량이 절반 밑으로 떨어졌어요... 하아암 🥱"
        case .melting:
            return "토큰이 얼마 안 남았어요! 몸이 축~~ 늘어져요 💦"
        case .liquid:
            return "잔여량 방전! 고양이 액체설 입증... 리셋 대기 중 💤"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .energetic: return Color.green
        case .content:   return Color.blue
        case .tired:     return Color.orange
        case .melting:   return Color(red: 0.95, green: 0.35, blue: 0.35)
        case .liquid:    return Color(red: 0.8, green: 0.2, blue: 0.5)
        }
    }
}

public enum CatStatusTarget: String, CaseIterable, Identifiable {
    case min = "min"          // 최저 잔여량 (가장 적게 남은 AI)
    case codex = "codex"      // OpenAI Codex
    case gemini = "gemini"    // Google Gemini
    case claude = "claude"    // Anthropic Claude
    case average = "average"  // 전체 평균 잔여량
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .min:     return "⚡️ 최저 잔여량 (가장 적게 남은 AI)"
        case .codex:   return "🤖 OpenAI Codex"
        case .gemini:  return "✨ Google Gemini"
        case .claude:  return "🧠 Anthropic Claude"
        case .average: return "📊 전체 평균 잔여량"
        }
    }
    
    public var shortName: String {
        switch self {
        case .min:     return "최저 잔여량"
        case .codex:   return "Codex"
        case .gemini:  return "Gemini"
        case .claude:  return "Claude"
        case .average: return "전체 평균"
        }
    }
}

