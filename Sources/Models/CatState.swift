import SwiftUI

public enum CatStage: Int, CaseIterable, Comparable {
    case energetic = 1  // 0% - 20% used
    case content = 2    // 21% - 50% used
    case tired = 3      // 51% - 75% used
    case melting = 4    // 76% - 90% used
    case liquid = 5     // 91% - 100% used
    
    public static func < (lhs: CatStage, rhs: CatStage) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public static func from(usedPercent: Double) -> CatStage {
        switch usedPercent {
        case ..<21.0:
            return .energetic
        case 21.0..<51.0:
            return .content
        case 51.0..<76.0:
            return .tired
        case 76.0..<91.0:
            return .melting
        default:
            return .liquid
        }
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
            return "기운이 펄펄 넘쳐요! 코딩 마음껏 하세요! ⚡️"
        case .content:
            return "안정적으로 작업 중이에요. 아직 여유 넘쳐냥 ☕️"
        case .tired:
            return "하아암... 사용량이 꽤 쌓여서 나른해져요 🥱"
        case .melting:
            return "몸이 점점 축~~ 늘어지는 중... 버텨볼게요 💦"
        case .liquid:
            return "토큰 완전 소진! 고양이 액체설 입증 완료... 쿨쿨 💤"
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
