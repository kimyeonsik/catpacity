import Foundation

public struct SubModelUsage: Identifiable, Codable {
    public var id: String { limitId }
    public let limitId: String
    public let limitName: String?
    public let usedPercent: Double
    public let resetsAt: Date?
    public let windowDurationMins: Int?
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
}

public struct CodexUsage: Codable {
    public var planType: String
    public var usedPercent: Double
    public var resetsAt: Date?
    public var windowDurationMins: Int?
    public var creditsBalance: String?
    public var hasCredits: Bool
    public var ordinaryUsageAllowed: Bool
    public var submodels: [SubModelUsage]
    public var lastUpdated: Date
    public var isConnected: Bool
    public var errorMessage: String?
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public static var initial: CodexUsage {
        CodexUsage(
            planType: "Codex Pro",
            usedPercent: 0,
            resetsAt: nil,
            windowDurationMins: nil,
            creditsBalance: "0",
            hasCredits: false,
            ordinaryUsageAllowed: true,
            submodels: [],
            lastUpdated: Date(),
            isConnected: false,
            errorMessage: nil
        )
    }
}

public struct GeminiUsage: Codable {
    public var planName: String
    public var usedPercent: Double
    public var usedRequests: Int?
    public var limitRequests: Int?
    public var remainingTokens: Int?
    public var limitTokens: Int?
    public var resetsAt: Date?
    public var lastUpdated: Date
    public var isConnected: Bool
    public var errorMessage: String?
    
    public var weeklyRemainingPercent: Double?
    public var weeklyResetsAt: Date?
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public static var initial: GeminiUsage {
        GeminiUsage(
            planName: UserDefaults.standard.string(forKey: "catpacity_gemini_plan_type") ?? "Gemini",
            usedPercent: 0,
            usedRequests: nil,
            limitRequests: nil,
            remainingTokens: nil,
            limitTokens: nil,
            resetsAt: nil,
            lastUpdated: Date(),
            isConnected: false,
            errorMessage: nil,
            weeklyRemainingPercent: nil,
            weeklyResetsAt: nil
        )
    }
}

public struct ClaudeUsage: Codable {
    public var planName: String
    public var usedPercent: Double
    public var resetsAt: Date?
    public var lastUpdated: Date
    public var isConnected: Bool
    public var errorMessage: String?
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public static var initial: ClaudeUsage {
        ClaudeUsage(
            planName: "Claude",
            usedPercent: 0,
            resetsAt: nil,
            lastUpdated: Date(),
            isConnected: false,
            errorMessage: nil
        )
    }
}

public struct OverallUsage {
    public var codex: CodexUsage
    public var gemini: GeminiUsage
    public var claude: ClaudeUsage
    
    public var maxUsedPercent: Double {
        var values: [Double] = []
        if codex.isConnected { values.append(codex.usedPercent) }
        if gemini.isConnected { values.append(gemini.usedPercent) }
        if claude.isConnected { values.append(claude.usedPercent) }
        return values.max() ?? 0.0
    }
    
    public var minRemainingPercent: Double {
        return max(0.0, 100.0 - maxUsedPercent)
    }
    
    public var catStage: CatStage {
        return CatStage.from(remainingPercent: minRemainingPercent)
    }
}
