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
    private static let cacheKey = "catpacity_codex_usage_cache"
    
    public static func loadCached() -> CodexUsage? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CodexUsage.self, from: data) else {
            return nil
        }
        return cached
    }
    
    public func saveCached() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: CodexUsage.cacheKey)
        }
    }
    
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
    public var isChecking: Bool = false
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public static var initial: CodexUsage {
        if let cached = loadCached(), cached.isConnected {
            var res = cached
            res.isChecking = true
            return res
        }
        return CodexUsage(
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
            errorMessage: "확인 중...",
            isChecking: true
        )
    }
}

public struct GeminiUsage: Codable {
    private static let cacheKey = "catpacity_gemini_usage_cache"
    
    public static func loadCached() -> GeminiUsage? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(GeminiUsage.self, from: data) else {
            return nil
        }
        return cached
    }
    
    public func saveCached() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: GeminiUsage.cacheKey)
        }
    }
    
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
    public var isChecking: Bool = false
    
    public var weeklyRemainingPercent: Double?
    public var weeklyResetsAt: Date?
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public static var initial: GeminiUsage {
        if let cached = loadCached(), cached.isConnected {
            var res = cached
            res.isChecking = true
            return res
        }
        return GeminiUsage(
            planName: UserDefaults.standard.string(forKey: "catpacity_gemini_plan_type") ?? "Gemini",
            usedPercent: 0,
            usedRequests: nil,
            limitRequests: nil,
            remainingTokens: nil,
            limitTokens: nil,
            resetsAt: nil,
            lastUpdated: Date(),
            isConnected: false,
            errorMessage: "확인 중...",
            isChecking: true,
            weeklyRemainingPercent: nil,
            weeklyResetsAt: nil
        )
    }
}

public struct ClaudeUsage: Codable {
    private static let cacheKey = "catpacity_claude_usage_cache"
    
    public static func loadCached() -> ClaudeUsage? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(ClaudeUsage.self, from: data) else {
            return nil
        }
        return cached
    }
    
    public func saveCached() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: ClaudeUsage.cacheKey)
        }
    }
    
    public var planName: String
    public var usedPercent: Double
    public var resetsAt: Date?
    public var lastUpdated: Date
    public var isConnected: Bool
    public var errorMessage: String?
    public var isChecking: Bool = false
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public static var initial: ClaudeUsage {
        if let cached = loadCached(), cached.isConnected {
            var res = cached
            res.isChecking = true
            return res
        }
        return ClaudeUsage(
            planName: "Claude",
            usedPercent: 0,
            resetsAt: nil,
            lastUpdated: Date(),
            isConnected: false,
            errorMessage: "확인 중...",
            isChecking: true
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
