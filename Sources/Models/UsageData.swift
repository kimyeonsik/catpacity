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

public enum ProviderUsageMode: Equatable {
    /// 케이스 2: 구독 요금제가 있고 한도 여유 있음 (안전지대)
    case subscriptionActive(remainingPercent: Double, resetsAt: Date?, hasApiKey: Bool)
    
    /// 케이스 3: 구독 요금제가 있고 한도가 모두 소진됨 (비상/과금 모드)
    case subscriptionExhausted(resetsAt: Date?, hasApiKey: Bool, apiEstimatedCost: Double?, apiUsedTokens: Int?)
    
    /// 케이스 1: 구독 요금제가 없고 순수 API 키 종량제 모드
    case payAsYouGoOnly(estimatedCost: Double, monthlyBudget: Double, usedTokens: Int?, remainingPercent: Double?)
    
    /// 미연동
    case disconnected(message: String)
}

public struct RateLimitResetCredit: Identifiable, Codable {
    public var id: String
    public var resetType: String?
    public var status: String?
    public var grantedAt: Date?
    public var expiresAt: Date?
    public var title: String?
    public var description: String?
    
    public init(
        id: String,
        resetType: String? = nil,
        status: String? = nil,
        grantedAt: Date? = nil,
        expiresAt: Date? = nil,
        title: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.resetType = resetType
        self.status = status
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.title = title
        self.description = description
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
    public var resetCreditsAvailableCount: Int = 0
    public var resetCredits: [RateLimitResetCredit] = []
    public var apiEstimatedCost: Double?
    public var apiUsedTokens: Int?
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public func currentMode(hasApiKey: Bool = false, monthlyBudget: Double = 50.0) -> ProviderUsageMode {
        guard isConnected else {
            if hasApiKey {
                return .payAsYouGoOnly(estimatedCost: apiEstimatedCost ?? 0.0, monthlyBudget: monthlyBudget, usedTokens: apiUsedTokens, remainingPercent: remainingPercent)
            }
            return .disconnected(message: errorMessage ?? "Codex 미연동")
        }
        if planType.contains("API") {
            return .payAsYouGoOnly(estimatedCost: apiEstimatedCost ?? 0.0, monthlyBudget: monthlyBudget, usedTokens: apiUsedTokens, remainingPercent: remainingPercent)
        }
        if ordinaryUsageAllowed && remainingPercent > 0.0 {
            return .subscriptionActive(remainingPercent: remainingPercent, resetsAt: resetsAt, hasApiKey: hasApiKey)
        } else {
            return .subscriptionExhausted(resetsAt: resetsAt, hasApiKey: hasApiKey, apiEstimatedCost: apiEstimatedCost, apiUsedTokens: apiUsedTokens)
        }
    }
    
    public init(
        planType: String,
        usedPercent: Double,
        resetsAt: Date? = nil,
        windowDurationMins: Int? = nil,
        creditsBalance: String? = nil,
        hasCredits: Bool = false,
        ordinaryUsageAllowed: Bool = true,
        submodels: [SubModelUsage] = [],
        lastUpdated: Date = Date(),
        isConnected: Bool = true,
        errorMessage: String? = nil,
        isChecking: Bool = false,
        resetCreditsAvailableCount: Int = 0,
        resetCredits: [RateLimitResetCredit] = [],
        apiEstimatedCost: Double? = nil,
        apiUsedTokens: Int? = nil
    ) {
        self.planType = planType
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.windowDurationMins = windowDurationMins
        self.creditsBalance = creditsBalance
        self.hasCredits = hasCredits
        self.ordinaryUsageAllowed = ordinaryUsageAllowed
        self.submodels = submodels
        self.lastUpdated = lastUpdated
        self.isConnected = isConnected
        self.errorMessage = errorMessage
        self.isChecking = isChecking
        self.resetCreditsAvailableCount = resetCreditsAvailableCount
        self.resetCredits = resetCredits
        self.apiEstimatedCost = apiEstimatedCost
        self.apiUsedTokens = apiUsedTokens
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planType = try container.decode(String.self, forKey: .planType)
        usedPercent = try container.decode(Double.self, forKey: .usedPercent)
        resetsAt = try container.decodeIfPresent(Date.self, forKey: .resetsAt)
        windowDurationMins = try container.decodeIfPresent(Int.self, forKey: .windowDurationMins)
        creditsBalance = try container.decodeIfPresent(String.self, forKey: .creditsBalance)
        hasCredits = try container.decode(Bool.self, forKey: .hasCredits)
        ordinaryUsageAllowed = try container.decode(Bool.self, forKey: .ordinaryUsageAllowed)
        submodels = try container.decode([SubModelUsage].self, forKey: .submodels)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        isConnected = try container.decode(Bool.self, forKey: .isConnected)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        isChecking = try container.decodeIfPresent(Bool.self, forKey: .isChecking) ?? false
        resetCreditsAvailableCount = try container.decodeIfPresent(Int.self, forKey: .resetCreditsAvailableCount) ?? 0
        resetCredits = try container.decodeIfPresent([RateLimitResetCredit].self, forKey: .resetCredits) ?? []
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
            isChecking: true,
            resetCreditsAvailableCount: 0,
            resetCredits: [],
            apiEstimatedCost: nil,
            apiUsedTokens: nil
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
    public var apiEstimatedCost: Double?
    public var apiUsedTokens: Int?
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public func currentMode(hasApiKey: Bool, monthlyBudget: Double = 50.0) -> ProviderUsageMode {
        guard isConnected else {
            if hasApiKey {
                return .payAsYouGoOnly(estimatedCost: apiEstimatedCost ?? 0.0, monthlyBudget: monthlyBudget, usedTokens: apiUsedTokens, remainingPercent: remainingPercent)
            }
            return .disconnected(message: errorMessage ?? "Gemini 미연동")
        }
        let isSubscription = planName.contains("@") || planName.contains("Antigravity")
        if isSubscription {
            if remainingPercent > 0.0 {
                return .subscriptionActive(remainingPercent: remainingPercent, resetsAt: resetsAt, hasApiKey: hasApiKey)
            } else {
                return .subscriptionExhausted(resetsAt: resetsAt, hasApiKey: hasApiKey, apiEstimatedCost: apiEstimatedCost, apiUsedTokens: apiUsedTokens)
            }
        } else if hasApiKey || planName.contains("API") {
            return .payAsYouGoOnly(estimatedCost: apiEstimatedCost ?? 0.0, monthlyBudget: monthlyBudget, usedTokens: apiUsedTokens, remainingPercent: remainingPercent)
        } else {
            if remainingPercent > 0.0 {
                return .subscriptionActive(remainingPercent: remainingPercent, resetsAt: resetsAt, hasApiKey: false)
            } else {
                return .subscriptionExhausted(resetsAt: resetsAt, hasApiKey: false, apiEstimatedCost: nil, apiUsedTokens: nil)
            }
        }
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
            weeklyResetsAt: nil,
            apiEstimatedCost: nil,
            apiUsedTokens: nil
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
    public var apiEstimatedCost: Double?
    public var apiUsedTokens: Int?
    
    public var remainingPercent: Double {
        return max(0.0, 100.0 - usedPercent)
    }
    
    public func currentMode(hasApiKey: Bool, monthlyBudget: Double = 50.0) -> ProviderUsageMode {
        guard isConnected else {
            if hasApiKey {
                return .payAsYouGoOnly(estimatedCost: apiEstimatedCost ?? 0.0, monthlyBudget: monthlyBudget, usedTokens: apiUsedTokens, remainingPercent: remainingPercent)
            }
            return .disconnected(message: errorMessage ?? "Claude 미연동")
        }
        let isSubscription = planName.contains("Pro") || planName.contains("Max")
        if isSubscription {
            if remainingPercent > 0.0 {
                return .subscriptionActive(remainingPercent: remainingPercent, resetsAt: resetsAt, hasApiKey: hasApiKey)
            } else {
                return .subscriptionExhausted(resetsAt: resetsAt, hasApiKey: hasApiKey, apiEstimatedCost: apiEstimatedCost, apiUsedTokens: apiUsedTokens)
            }
        } else if hasApiKey || planName.contains("API") {
            return .payAsYouGoOnly(estimatedCost: apiEstimatedCost ?? 0.0, monthlyBudget: monthlyBudget, usedTokens: apiUsedTokens, remainingPercent: remainingPercent)
        } else {
            if remainingPercent > 0.0 {
                return .subscriptionActive(remainingPercent: remainingPercent, resetsAt: resetsAt, hasApiKey: false)
            } else {
                return .subscriptionExhausted(resetsAt: resetsAt, hasApiKey: false, apiEstimatedCost: nil, apiUsedTokens: nil)
            }
        }
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
            isChecking: true,
            apiEstimatedCost: nil,
            apiUsedTokens: nil
        )
    }
}

public struct OverallUsage {
    public var codex: CodexUsage
    public var gemini: GeminiUsage
    public var claude: ClaudeUsage
    
    public func maxUsedPercent(showCodex: Bool = true, showGemini: Bool = true, showClaude: Bool = true) -> Double {
        var values: [Double] = []
        if showCodex && codex.isConnected { values.append(codex.usedPercent) }
        if showGemini && gemini.isConnected { values.append(gemini.usedPercent) }
        if showClaude && claude.isConnected { values.append(claude.usedPercent) }
        return values.max() ?? 0.0
    }
    
    public func minRemainingPercent(showCodex: Bool = true, showGemini: Bool = true, showClaude: Bool = true) -> Double {
        var values: [Double] = []
        if showCodex && codex.isConnected { values.append(codex.remainingPercent) }
        if showGemini && gemini.isConnected { values.append(gemini.remainingPercent) }
        if showClaude && claude.isConnected { values.append(claude.remainingPercent) }
        if values.isEmpty {
            return 100.0
        }
        return values.min() ?? 100.0
    }
    
    public func remainingPercent(
        for target: CatStatusTarget,
        showCodex: Bool = true,
        showGemini: Bool = true,
        showClaude: Bool = true
    ) -> (percent: Double, targetName: String) {
        switch target {
        case .codex:
            if codex.isConnected {
                return (codex.remainingPercent, "OpenAI Codex")
            } else {
                let fallback = minRemainingPercent(showCodex: false, showGemini: showGemini, showClaude: showClaude)
                return (fallback, "최저 잔여량 (Codex 미연동)")
            }
        case .gemini:
            if gemini.isConnected {
                return (gemini.remainingPercent, "Google Gemini")
            } else {
                let fallback = minRemainingPercent(showCodex: showCodex, showGemini: false, showClaude: showClaude)
                return (fallback, "최저 잔여량 (Gemini 미연동)")
            }
        case .claude:
            if claude.isConnected {
                return (claude.remainingPercent, "Anthropic Claude")
            } else {
                let fallback = minRemainingPercent(showCodex: showCodex, showGemini: showGemini, showClaude: false)
                return (fallback, "최저 잔여량 (Claude 미연동)")
            }
        case .average:
            var values: [Double] = []
            if showCodex && codex.isConnected { values.append(codex.remainingPercent) }
            if showGemini && gemini.isConnected { values.append(gemini.remainingPercent) }
            if showClaude && claude.isConnected { values.append(claude.remainingPercent) }
            if values.isEmpty {
                return (100.0, "전체 평균")
            }
            let avg = values.reduce(0.0, +) / Double(values.count)
            return (avg, "전체 평균")
        case .min:
            var items: [(name: String, rem: Double)] = []
            if showCodex && codex.isConnected { items.append(("Codex", codex.remainingPercent)) }
            if showGemini && gemini.isConnected { items.append(("Gemini", gemini.remainingPercent)) }
            if showClaude && claude.isConnected { items.append(("Claude", claude.remainingPercent)) }
            if let minItem = items.min(by: { $0.rem < $1.rem }) {
                return (minItem.rem, "최저: \(minItem.name)")
            } else {
                return (100.0, "최저 잔여량")
            }
        }
    }

    
    public var maxUsedPercent: Double {
        return maxUsedPercent()
    }
    
    public var minRemainingPercent: Double {
        return minRemainingPercent()
    }
    
    public var catStage: CatStage {
        return CatStage.from(remainingPercent: minRemainingPercent)
    }
}
