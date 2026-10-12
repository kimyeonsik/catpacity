import Foundation

public class ClaudeService {
    public static let shared = ClaudeService()
    
    private let defaults = UserDefaults.standard
    private let apiKeyKey = "catpacity_claude_api_key"
    private let planOverrideKey = "catpacity_claude_plan_override"
    
    public var apiKey: String {
        get { defaults.string(forKey: apiKeyKey) ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "" }
        set { defaults.set(newValue, forKey: apiKeyKey) }
    }
    
    public var planOverride: String {
        get { defaults.string(forKey: planOverrideKey) ?? "auto" }
        set { defaults.set(newValue, forKey: planOverrideKey) }
    }
    
    private var isFetching = false
    public var lastKnownValidUsage: ClaudeUsage? = ClaudeUsage.loadCached()
    
    public func fetchUsage(completion: @escaping (ClaudeUsage) -> Void) {
        if isFetching {
            if let cached = lastKnownValidUsage {
                completion(cached)
            } else {
                completion(ClaudeUsage.initial)
            }
            return
        }
        isFetching = true
        
        let completionWrapper: (ClaudeUsage) -> Void = { [weak self] usage in
            self?.isFetching = false
            if usage.isConnected {
                self?.lastKnownValidUsage = usage
                usage.saveCached()
                completion(usage)
            } else if var cached = self?.lastKnownValidUsage, cached.isConnected {
                cached.lastUpdated = Date()
                cached.isChecking = false
                completion(cached)
            } else {
                completion(usage)
            }
        }
        
        let key = self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1순위: 공식 실시간 쿼터 소스들 (Claude Desktop 앱 히스토리, Claude Code 실시간 훅, ~/.claude.json 캐시)
        // 존재하는 공식 데이터 중 가장 최근(lastUpdated) 데이터를 최우선 적용
        var officialCandidates: [ClaudeUsage] = []
        if let desktop = readDesktopPlanUsage() {
            officialCandidates.append(desktop)
        }
        if let codeHook = readClaudeCodeQuotaHook() {
            officialCandidates.append(codeHook)
        }
        if let codeCache = readClaudeJsonCache() {
            officialCandidates.append(codeCache)
        }
        
        if let bestOfficial = officialCandidates.sorted(by: { $0.lastUpdated > $1.lastUpdated }).first {
            var finalUsage = bestOfficial
            if !key.isEmpty {
                self.fetchApiCostOnly(key: key) { cost, tokens in
                    finalUsage.apiEstimatedCost = cost
                    finalUsage.apiUsedTokens = tokens
                    completionWrapper(finalUsage)
                }
            } else {
                completionWrapper(finalUsage)
            }
            return
        }
        
        // 2순위: 로컬 Claude CLI 또는 ~/.claude.json 로그인 세션 확인 (추정 토큰 Fallback)
        let hasCli = findClaudeBinary() != nil
        let localConfig = parseClaudeJsonConfig()
        
        if hasCli || localConfig != nil {
            checkClaudeCliAuth { [weak self] cliUsage in
                guard let self = self else { return }
                
                let isSubscription = cliUsage.isConnected && (
                    cliUsage.planName.contains("Pro") ||
                    cliUsage.planName.contains("Max") ||
                    cliUsage.planName.contains("Team") ||
                    cliUsage.planName.contains("Enterprise") ||
                    cliUsage.planName.localizedCaseInsensitiveContains("team") ||
                    cliUsage.planName.contains("Desktop")
                )
                
                if isSubscription {
                    var finalUsage = cliUsage
                    if !key.isEmpty {
                        self.fetchApiCostOnly(key: key) { cost, tokens in
                            finalUsage.apiEstimatedCost = cost
                            finalUsage.apiUsedTokens = tokens
                            completionWrapper(finalUsage)
                        }
                    } else {
                        completionWrapper(finalUsage)
                    }
                } else if !key.isEmpty {
                    self.fetchWithApiKey(key: key, completion: completionWrapper)
                } else {
                    completionWrapper(cliUsage)
                }
            }
        } else if !key.isEmpty {
            fetchWithApiKey(key: key, completion: completionWrapper)
        } else {
            checkClaudeCliAuth(completion: completionWrapper)
        }
    }
    
    private func findClaudeBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.bun/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "\(home)/Library/pnpm/claude",
            "\(home)/.local/share/pnpm/claude",
            "\(home)/.yarn/bin/claude",
            "\(home)/.volta/bin/claude",
            "\(home)/.asdf/shims/claude",
            "\(home)/.local/share/mise/shims/claude",
            "\(home)/.local/share/fnm/current/bin/claude",
            "\(home)/Library/Application Support/fnm/current/bin/claude",
            "/usr/bin/claude"
        ]
        
        // Scan nvm node versions if present
        let nvmNodeDir = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmNodeDir) {
            for v in versions.sorted().reversed() {
                candidates.insert("\(nvmNodeDir)/\(v)/bin/claude", at: 0)
            }
        }
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.components(separatedBy: ":") {
                let candidate = (dir as NSString).appendingPathComponent("claude")
                if FileManager.default.fileExists(atPath: candidate) {
                    return candidate
                }
            }
        }
        
        // Dynamic search in user shell environment via 'which claude'
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
        whichProcess.arguments = ["-ilc", "which claude"]
        whichProcess.environment = EnvironmentHelper.makeProcessEnvironment()
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = Pipe()
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty, FileManager.default.fileExists(atPath: output) {
                return output
            }
        } catch {}
        
        return nil
    }
    
    private func parseClaudeJsonConfig() -> (planName: String, isConnected: Bool, errorMessage: String?)? {
        let override = self.planOverride
        if override == "free" {
            return (planName: "Claude Free", isConnected: true, errorMessage: nil)
        } else if override == "team" {
            return (planName: "Claude Team", isConnected: true, errorMessage: nil)
        } else if override == "enterprise" {
            return (planName: "Claude Enterprise", isConnected: true, errorMessage: nil)
        } else if override == "max" {
            return (planName: "Claude Max", isConnected: true, errorMessage: nil)
        } else if override == "pro" {
            return (planName: "Claude Pro", isConnected: true, errorMessage: nil)
        }
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".claude.json").path,
            home.appendingPathComponent(".claude/.claude.json").path
        ]
        
        for path in candidates {
            guard let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            if let oauth = json["oauthAccount"] as? [String: Any],
               (oauth["accountUuid"] != nil || oauth["emailAddress"] != nil) {
                let orgType = (oauth["organizationType"] as? String ?? "").lowercased()
                let rateTier = (oauth["organizationRateLimitTier"] as? String ?? "").lowercased()
                let billing = (oauth["billingType"] as? String ?? "").lowercased()
                let seatTier = (oauth["seatTier"] as? String ?? "").lowercased()
                let orgRole = (oauth["organizationRole"] as? String ?? "").lowercased()
                let orgName = oauth["organizationName"] as? String ?? ""
                let userTier = (oauth["userRateLimitTier"] as? String ?? "").lowercased()
                
                var planName = "Claude Pro"
                let isTeam = orgType.contains("team") ||
                             rateTier.contains("team") ||
                             seatTier.contains("team") ||
                             billing.contains("team") ||
                             orgRole.contains("team") ||
                             userTier.contains("team") ||
                             orgName.lowercased().contains("team")
                
                let isEnterprise = orgType.contains("enterprise") ||
                                   rateTier.contains("enterprise") ||
                                   billing.contains("enterprise") ||
                                   seatTier.contains("enterprise")
                
                let profileFetchedAtMs = oauth["profileFetchedAt"] as? Double ?? 0
                let isProfileStale: Bool = {
                    if profileFetchedAtMs > 0 {
                        let fetchedDate = Date(timeIntervalSince1970: profileFetchedAtMs / 1000.0)
                        return Date().timeIntervalSince(fetchedDate) > 30 * 86400
                    }
                    return false
                }()
                
                if isTeam {
                    if !orgName.isEmpty && !orgName.contains("@") && !orgName.lowercased().contains("organization") {
                        planName = "Claude Team (\(orgName))"
                    } else {
                        planName = "Claude Team"
                    }
                } else if isEnterprise {
                    if !orgName.isEmpty && !orgName.contains("@") && !orgName.lowercased().contains("organization") {
                        planName = "Claude Enterprise (\(orgName))"
                    } else {
                        planName = "Claude Enterprise"
                    }
                } else if !isProfileStale && (billing.contains("subscription") || orgType.contains("pro") || rateTier.contains("pro") || orgType.contains("max") || rateTier.contains("max")) {
                    // Anthropic은 Pro 구독자에게 내부적으로 Sonnet 1M/5x 티어(claude_max)를 부여하므로 공식 명칭인 Claude Pro로 표시 (단, 최근 30일 이내 유효 프로필에 한함)
                    planName = "Claude Pro"
                } else if billing.isEmpty || billing == "none" || billing.contains("free") || orgType.contains("free") || rateTier.contains("free") || isProfileStale {
                    planName = "Claude Free"
                } else {
                    let cleaned = orgType.replacingOccurrences(of: "claude_", with: "").capitalized
                    planName = cleaned.isEmpty ? "Claude Free" : "Claude \(cleaned)"
                }
                
                return (planName: planName, isConnected: true, errorMessage: nil)
            }
        }
        return nil
    }
    
    private func calculateRecent5HourUsage(planName: String) -> (usedPercent: Double, usedTokens: Int, nextReset: Date?, weeklyUsedPercent: Double?) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let projectsDir = home + "/.claude/projects"
        let fiveHoursAgo = Date().addingTimeInterval(-5 * 3600)
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        
        var totalTokens = 0
        var totalWeeklyTokens = 0
        var earliestCallTime: Date? = nil
        
        if FileManager.default.fileExists(atPath: projectsDir),
           let enumerator = FileManager.default.enumerator(atPath: projectsDir) {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallbackFormatter = ISO8601DateFormatter()
            
            while let file = enumerator.nextObject() as? String {
                guard file.hasSuffix(".jsonl") else { continue }
                let fullPath = "\(projectsDir)/\(file)"
                
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date,
                      modDate >= sevenDaysAgo else {
                    continue
                }
                
                if let data = FileManager.default.contents(atPath: fullPath),
                   let content = String(data: data, encoding: .utf8) {
                    let lines = content.components(separatedBy: "\n")
                    for line in lines where line.contains("\"usage\"") {
                        guard let lineData = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                              let message = json["message"] as? [String: Any],
                              let usage = message["usage"] as? [String: Any] else {
                            continue
                        }
                        
                        let inTok = usage["input_tokens"] as? Int ?? 0
                        let outTok = usage["output_tokens"] as? Int ?? 0
                        let lineTokens = inTok + outTok
                        
                        var callDate: Date? = nil
                        if let tsStr = json["timestamp"] as? String {
                            callDate = isoFormatter.date(from: tsStr) ?? fallbackFormatter.date(from: tsStr)
                        } else if let tsNum = json["timestamp"] as? Double {
                            callDate = Date(timeIntervalSince1970: tsNum > 1e11 ? tsNum / 1000.0 : tsNum)
                        }
                        
                        if let d = callDate {
                            if d >= sevenDaysAgo {
                                totalWeeklyTokens += lineTokens
                            }
                            if d >= fiveHoursAgo {
                                totalTokens += lineTokens
                                if earliestCallTime == nil || d < earliestCallTime! {
                                    earliestCallTime = d
                                }
                            }
                        } else {
                            totalWeeklyTokens += lineTokens
                            totalTokens += lineTokens
                        }
                    }
                }
            }
        }
        
        let limitTokens: Double
        let weeklyLimitTokens: Double
        if planName.contains("Max") {
            limitTokens = 1_000_000.0
            weeklyLimitTokens = 5_000_000.0
        } else if planName.contains("Enterprise") {
            limitTokens = 1_500_000.0
            weeklyLimitTokens = 7_500_000.0
        } else if planName.contains("Team") {
            limitTokens = 500_000.0
            weeklyLimitTokens = 2_500_000.0
        } else {
            limitTokens = 150_000.0 // Pro default
            weeklyLimitTokens = 750_000.0
        }
        
        let calculatedPercent = min(100.0, max(0.0, Double(totalTokens) / limitTokens * 100.0))
        let weeklyPercent = min(100.0, max(0.0, Double(totalWeeklyTokens) / weeklyLimitTokens * 100.0))
        
        let nextReset: Date?
        if let earliest = earliestCallTime {
            nextReset = earliest.addingTimeInterval(5 * 3600)
        } else {
            nextReset = nil // 토큰 소모가 없으면 세션 타이머 미시작!
        }
        
        return (usedPercent: calculatedPercent, usedTokens: totalTokens, nextReset: nextReset, weeklyUsedPercent: weeklyPercent)
    }
    
    private func checkClaudeCliAuth(completion: @escaping (ClaudeUsage) -> Void) {
        guard let binary = findClaudeBinary() else {
            // 사용자가 설정에서 수동으로 플랜을 지정한 경우에만 해당 오버라이드 플랜 표시
            if self.planOverride != "auto", let parsed = parseClaudeJsonConfig(), parsed.isConnected {
                let usageInfo = calculateRecent5HourUsage(planName: parsed.planName)
                DispatchQueue.main.async {
                    completion(ClaudeUsage(
                        planName: parsed.planName,
                        usedPercent: usageInfo.usedPercent,
                        resetsAt: usageInfo.nextReset,
                        lastUpdated: Date(),
                        isConnected: true,
                        errorMessage: nil,
                        isChecking: false,
                        apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil,
                        weeklyUsedPercent: usageInfo.weeklyUsedPercent
                    ))
                }
                return
            }
            
            if var cached = self.lastKnownValidUsage, cached.isConnected {
                cached.lastUpdated = Date()
                cached.isChecking = false
                DispatchQueue.main.async { completion(cached) }
            } else {
                DispatchQueue.main.async {
                    completion(ClaudeUsage(
                        planName: "미연동",
                        usedPercent: 0.0,
                        resetsAt: nil,
                        lastUpdated: Date(),
                        isConnected: false,
                        errorMessage: "Claude 미연동: CLI 미설치('npm i -g @anthropic-ai/claude-code') 또는 API 키 필요"
                    ))
                }
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = ["auth", "status", "--json"]
            process.environment = EnvironmentHelper.makeProcessEnvironment()
            process.standardInput = FileHandle.nullDevice
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            
            var didComplete = false
            
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + 12.0)
            timer.setEventHandler {
                if !didComplete {
                    didComplete = true
                    process.terminate()
                    
                    // 타임아웃 발생 시: 수동 오버라이드 플랜이 있는 경우에만 적용
                    if self.planOverride != "auto", let parsed = self.parseClaudeJsonConfig(), parsed.isConnected {
                        let usageInfo = self.calculateRecent5HourUsage(planName: parsed.planName)
                        DispatchQueue.main.async {
                            completion(ClaudeUsage(
                                planName: parsed.planName,
                                usedPercent: usageInfo.usedPercent,
                                resetsAt: usageInfo.nextReset,
                                lastUpdated: Date(),
                                isConnected: true,
                                errorMessage: nil,
                                isChecking: false,
                                apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil,
                                weeklyUsedPercent: usageInfo.weeklyUsedPercent
                            ))
                        }
                    } else if var cached = self.lastKnownValidUsage, cached.isConnected {
                        cached.lastUpdated = Date()
                        cached.isChecking = false
                        DispatchQueue.main.async {
                            completion(cached)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(ClaudeUsage(
                                planName: "미연동",
                                usedPercent: 0.0,
                                resetsAt: nil,
                                lastUpdated: Date(),
                                isConnected: false,
                                errorMessage: "Claude 인증 확인 시간 초과",
                                isChecking: false
                            ))
                        }
                    }
                }
            }
            timer.resume()
            
            var outputData = Data()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty {
                    outputData.append(chunk)
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
                outputData.append(remaining)
                
                if didComplete { return }
                didComplete = true
                timer.cancel()
                
                // Safe JSON parsing handling trailing ANSI escape codes
                let json = self.parseAuthStatusJson(from: outputData)
                let loggedIn = (json?["loggedIn"] as? Bool) ?? false
                
                if !loggedIn {
                    // 사용자가 설정에서 수동으로 특정 플랜을 지정한 경우에만 해당 오버라이드 플랜을 표시
                    if self.planOverride != "auto", let parsed = self.parseClaudeJsonConfig(), parsed.isConnected {
                        let usageInfo = self.calculateRecent5HourUsage(planName: parsed.planName)
                        DispatchQueue.main.async {
                            completion(ClaudeUsage(
                                planName: parsed.planName,
                                usedPercent: usageInfo.usedPercent,
                                resetsAt: usageInfo.nextReset,
                                lastUpdated: Date(),
                                isConnected: true,
                                errorMessage: nil,
                                isChecking: false,
                                apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil,
                                weeklyUsedPercent: usageInfo.weeklyUsedPercent
                            ))
                        }
                        return
                    }
                    
                    UserDefaults.standard.removeObject(forKey: "catpacity_claude_usage_cache")
                    self.lastKnownValidUsage = nil
                    DispatchQueue.main.async {
                        completion(ClaudeUsage(
                            planName: "미연동",
                            usedPercent: 0.0,
                            resetsAt: nil,
                            lastUpdated: Date(),
                            isConnected: false,
                            errorMessage: "Claude 미연동: CLI 로그인 세션 만료 ('claude login' 필요) 또는 Desktop 앱 실행 필요",
                            isChecking: false
                        ))
                    }
                    return
                }
                
                // Active login confirmed (loggedIn == true)
                self.fetchFromLocalClaudeConfig(completion: completion)
            } catch {
                if didComplete { return }
                didComplete = true
                timer.cancel()
                
                if self.planOverride != "auto", let parsed = self.parseClaudeJsonConfig(), parsed.isConnected {
                    let usageInfo = self.calculateRecent5HourUsage(planName: parsed.planName)
                    DispatchQueue.main.async {
                        completion(ClaudeUsage(
                            planName: parsed.planName,
                            usedPercent: usageInfo.usedPercent,
                            resetsAt: usageInfo.nextReset,
                            lastUpdated: Date(),
                            isConnected: true,
                            errorMessage: nil,
                            isChecking: false,
                            apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil,
                            weeklyUsedPercent: usageInfo.weeklyUsedPercent
                        ))
                    }
                } else if var cached = self.lastKnownValidUsage, cached.isConnected {
                    cached.lastUpdated = Date()
                    cached.isChecking = false
                    DispatchQueue.main.async {
                        completion(cached)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(ClaudeUsage(
                            planName: "미연동",
                            usedPercent: 0.0,
                            resetsAt: nil,
                            lastUpdated: Date(),
                            isConnected: false,
                            errorMessage: "Claude 인증 프로세스 실행 실패",
                            isChecking: false
                        ))
                    }
                }
            }
        }
    }
    
    private func parseAuthStatusJson(from data: Data) -> [String: Any]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}") else { return nil }
        let jsonSub = String(text[firstBrace...lastBrace])
        guard let cleanData = jsonSub.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: cleanData) as? [String: Any]
    }
    
    private func fetchFromLocalClaudeConfig(completion: @escaping (ClaudeUsage) -> Void) {
        if let parsed = parseClaudeJsonConfig(), parsed.isConnected {
            let usageInfo = calculateRecent5HourUsage(planName: parsed.planName)
            DispatchQueue.main.async {
                completion(ClaudeUsage(
                    planName: parsed.planName,
                    usedPercent: usageInfo.usedPercent,
                    resetsAt: usageInfo.nextReset,
                    lastUpdated: Date(),
                    isConnected: true,
                    errorMessage: nil,
                    isChecking: false,
                    apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil,
                    weeklyUsedPercent: usageInfo.weeklyUsedPercent
                ))
            }
        } else {
            DispatchQueue.main.async {
                completion(ClaudeUsage(
                    planName: "미연동",
                    usedPercent: 0.0,
                    resetsAt: nil,
                    lastUpdated: Date(),
                    isConnected: false,
                    errorMessage: "Claude 계정 로그인 정보 없음 ('claude login' 필요)"
                ))
            }
        }
    }
    
    private func fetchWithApiKey(key: String, completion: @escaping (ClaudeUsage) -> Void) {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            checkClaudeCliAuth(completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let remainingTok = httpResponse.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-remaining").flatMap { Int($0) }
                    let limitTok = httpResponse.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-limit").flatMap { Int($0) }
                    
                    var usedPercent: Double = 0.0
                    if let rem = remainingTok, let lim = limitTok, lim > 0 {
                        usedPercent = Double(lim - rem) / Double(lim) * 100.0
                    }
                    
                    let usedTokens = (limitTok != nil && remainingTok != nil && limitTok! >= remainingTok!) ? (limitTok! - remainingTok!) : nil
                    let estimatedCost = usedTokens != nil ? Double(usedTokens!) * 0.000009 : nil
                    
                    DispatchQueue.main.async {
                        completion(ClaudeUsage(
                            planName: "Anthropic API",
                            usedPercent: min(100.0, max(0.0, usedPercent)),
                            resetsAt: nil,
                            lastUpdated: Date(),
                            isConnected: true,
                            errorMessage: nil,
                            apiEstimatedCost: estimatedCost,
                            apiUsedTokens: usedTokens
                        ))
                    }
                    return
                }
            }
            
            self.checkClaudeCliAuth(completion: completion)
        }.resume()
    }
    
    private func fetchApiCostOnly(key: String, completion: @escaping (Double?, Int?) -> Void) {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            completion(nil, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6.0
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let remainingTok = httpResponse.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-remaining").flatMap { Int($0) }
                let limitTok = httpResponse.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-limit").flatMap { Int($0) }
                let usedTokens = (limitTok != nil && remainingTok != nil && limitTok! >= remainingTok!) ? (limitTok! - remainingTok!) : nil
                let cost = usedTokens != nil ? Double(usedTokens!) * 0.000009 : nil
                DispatchQueue.main.async {
                    completion(cost, usedTokens)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
            }
        }.resume()
    }
    
    // MARK: - 1. Claude Desktop App Official Usage (~/Library/Application Support/Claude/plan-usage-history.json)
    public func readDesktopPlanUsage() -> ClaudeUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let historyPath = home.appendingPathComponent("Library/Application Support/Claude/plan-usage-history.json").path
        guard FileManager.default.fileExists(atPath: historyPath),
              let data = FileManager.default.contents(atPath: historyPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let samples = json["samples"] as? [[String: Any]],
              let lastSample = samples.last,
              let timestampMs = lastSample["t"] as? Double,
              let u = lastSample["u"] as? [String: Any] else {
            return nil
        }
        
        let sampleDate = Date(timeIntervalSince1970: timestampMs / 1000.0)
        let now = Date()
        
        // 마지막 샘플이 24시간 이상 지난 과거 파일이라면 현재 활성 상태가 아니므로 무시
        guard now.timeIntervalSince(sampleDate) < 24 * 3600 else {
            return nil
        }
        
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        
        // 5시간 쿼터 소모율 (fh)
        let fh = (u["fh"] as? Double) ?? Double(u["fh"] as? Int ?? 0)
        // 7일 주간 쿼터 소모율 (sd)
        let sd = (u["sd"] as? Double) ?? (u["sd"] as? Int).map { Double($0) }
        
        // 5시간 세션 리셋 시간 및 사용량 계산
        let currentUsedPercent: Double
        let resetDate: Date?
        
        if sampleDate >= fiveHoursAgo && fh > 0 {
            currentUsedPercent = min(100.0, max(0.0, fh))
            
            // 이번 5시간 세션이 시작된 최초 시점(fh가 증가하기 시작한 첫 샘플)을 역추적
            var sessionStartDate = sampleDate
            for s in samples.reversed() {
                guard let tMs = s["t"] as? Double else { continue }
                let sDate = Date(timeIntervalSince1970: tMs / 1000.0)
                if sDate < fiveHoursAgo { break }
                if let sU = s["u"] as? [String: Any] {
                    let sFh = (sU["fh"] as? Double) ?? Double(sU["fh"] as? Int ?? 0)
                    if sFh > 0 {
                        sessionStartDate = sDate
                    } else {
                        break
                    }
                }
            }
            resetDate = sessionStartDate.addingTimeInterval(5 * 3600)
        } else {
            // 마지막 샘플이 5시간 이상 전이거나 fh == 0이면 세션 미사용 상태
            currentUsedPercent = 0.0
            resetDate = nil
        }
        
        // 플랜 이름 결정
        var planName = "Claude Desktop"
        if let local = parseClaudeJsonConfig(), local.isConnected {
            planName = local.planName
        } else if planOverride == "team" {
            planName = "Claude Team"
        } else if planOverride == "enterprise" {
            planName = "Claude Enterprise"
        } else if planOverride == "max" {
            planName = "Claude Max"
        } else if planOverride == "pro" {
            planName = "Claude Pro"
        }
        
        let activeOrg = lastSample["org"] as? String
        
        return ClaudeUsage(
            planName: planName,
            usedPercent: currentUsedPercent,
            resetsAt: resetDate,
            lastUpdated: sampleDate,
            isConnected: true,
            errorMessage: nil,
            isChecking: false,
            apiEstimatedCost: nil,
            apiUsedTokens: nil,
            weeklyUsedPercent: sd,
            source: "Claude Desktop 앱",
            activeOrg: activeOrg
        )
    }
    
    // MARK: - 2. Claude Code Real-Time Quota Hook (~/.catpacity/claude_quota.json)
    public func readClaudeCodeQuotaHook() -> ClaudeUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let quotaPath = home.appendingPathComponent(".catpacity/claude_quota.json").path
        guard FileManager.default.fileExists(atPath: quotaPath),
              let data = FileManager.default.contents(atPath: quotaPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let rateLimits = (json["rate_limits"] as? [String: Any]) ?? json
        guard let fiveHour = rateLimits["five_hour"] as? [String: Any] else {
            return nil
        }
        
        let usedPct = (fiveHour["used_percentage"] as? Double) ?? Double(fiveHour["used_percentage"] as? Int ?? 0)
        var resetDate: Date? = nil
        if let resetsAtSec = fiveHour["resets_at"] as? Double {
            resetDate = Date(timeIntervalSince1970: resetsAtSec)
        }
        
        var weeklyPct: Double? = nil
        var weeklyResetDate: Date? = nil
        if let sevenDay = rateLimits["seven_day"] as? [String: Any] {
            weeklyPct = (sevenDay["used_percentage"] as? Double) ?? (sevenDay["used_percentage"] as? Int).map { Double($0) }
            if let resetsAtSec = sevenDay["resets_at"] as? Double {
                weeklyResetDate = Date(timeIntervalSince1970: resetsAtSec)
            }
        }
        
        let modDate = (try? FileManager.default.attributesOfItem(atPath: quotaPath)[.modificationDate] as? Date) ?? Date()
        
        var planName = "Claude Code"
        if let local = parseClaudeJsonConfig(), local.isConnected {
            planName = local.planName
        } else if planOverride == "team" {
            planName = "Claude Team"
        }
        
        return ClaudeUsage(
            planName: planName,
            usedPercent: min(100.0, max(0.0, usedPct)),
            resetsAt: resetDate,
            lastUpdated: modDate,
            isConnected: true,
            errorMessage: nil,
            isChecking: false,
            weeklyUsedPercent: weeklyPct,
            weeklyResetsAt: weeklyResetDate,
            source: "Claude Code 실시간 훅"
        )
    }
    
    // MARK: - 3. Claude Code ~/.claude.json cachedUsageUtilization
    public func readClaudeJsonCache() -> ClaudeUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".claude.json").path,
            home.appendingPathComponent(".claude/.claude.json").path
        ]
        
        for path in candidates {
            guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cache = json["cachedUsageUtilization"] as? [String: Any],
              let util = cache["utilization"] as? [String: Any],
              let fiveHour = util["five_hour"] as? [String: Any] else {
                continue
            }
            
            let usedPct = (fiveHour["utilization"] as? Double) ?? Double(fiveHour["utilization"] as? Int ?? 0)
            var resetDate: Date? = nil
            if let resetsAt = fiveHour["resets_at"] as? String {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                resetDate = iso.date(from: resetsAt) ?? ISO8601DateFormatter().date(from: resetsAt)
            } else if let resetsAtSec = fiveHour["resets_at"] as? Double {
                resetDate = Date(timeIntervalSince1970: resetsAtSec)
            }
            
            var weeklyPct: Double? = nil
            var weeklyResetDate: Date? = nil
            if let sevenDay = util["seven_day"] as? [String: Any] {
                weeklyPct = (sevenDay["utilization"] as? Double) ?? (sevenDay["utilization"] as? Int).map { Double($0) }
                if let resetsAt = sevenDay["resets_at"] as? String {
                    let iso = ISO8601DateFormatter()
                    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    weeklyResetDate = iso.date(from: resetsAt) ?? ISO8601DateFormatter().date(from: resetsAt)
                } else if let resetsAtSec = sevenDay["resets_at"] as? Double {
                    weeklyResetDate = Date(timeIntervalSince1970: resetsAtSec)
                }
            }
            
            let fetchedAtMs = cache["fetchedAtMs"] as? Double ?? 0
            let cacheDate = fetchedAtMs > 0 ? Date(timeIntervalSince1970: fetchedAtMs / 1000.0) : Date()
            
            var planName = "Claude Code"
            if let local = parseClaudeJsonConfig(), local.isConnected {
                planName = local.planName
            } else if planOverride == "team" {
                planName = "Claude Team"
            }
            
            return ClaudeUsage(
                planName: planName,
                usedPercent: min(100.0, max(0.0, usedPct)),
                resetsAt: resetDate,
                lastUpdated: cacheDate,
                isConnected: true,
                errorMessage: nil,
                isChecking: false,
                weeklyUsedPercent: weeklyPct,
                weeklyResetsAt: weeklyResetDate,
                source: "Claude Code 캐시"
            )
        }
        return nil
    }
    
    // MARK: - 4. Claude Code statusLine Hook One-Click Setup
    public func setupClaudeCodeIntegration() -> (success: Bool, message: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let catpacityDir = home.appendingPathComponent(".catpacity").path
        
        do {
            try FileManager.default.createDirectory(atPath: catpacityDir, withIntermediateDirectories: true)
        } catch {
            return (false, "디렉토리 생성 실패 (~/.catpacity): \(error.localizedDescription)")
        }
        
        let settingsDir = home.appendingPathComponent(".claude").path
        let settingsPath = "\(settingsDir)/settings.json"
        
        try? FileManager.default.createDirectory(atPath: settingsDir, withIntermediateDirectories: true)
        
        var settings: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }
        
        let hookCommand = "sh -c 'cat > ~/.catpacity/claude_quota.json'"
        settings["statusLine"] = [
            "command": hookCommand
        ]
        
        do {
            let outData = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted])
            try outData.write(to: URL(fileURLWithPath: settingsPath))
            return (true, "연동 등록 완료! 터미널에서 claude를 실행하면 쿼터가 실시간 자동 동기화됩니다.")
        } catch {
            return (false, "settings.json 저장 실패: \(error.localizedDescription)")
        }
    }
    
    public var hasCliInstalled: Bool {
        return findClaudeBinary() != nil
    }
    
    // MARK: - 5. Terminal OAuth Login Flow ('claude login')
    public func launchTerminalLogin(completion: (() -> Void)? = nil) {
        // 실시간 쿼터 훅도 사전에 미리 등록해 둠
        _ = setupClaudeCodeIntegration()
        
        let binary = findClaudeBinary()
        let command: String
        if let bin = binary {
            command = "\(bin) login"
        } else {
            command = "echo '🐱 Catpacity: Claude CLI를 확인하거나 설치 후 로그인을 진행합니다...' && (command -v claude >/dev/null 2>&1 && claude login || (npm install -g @anthropic-ai/claude-code && claude login))"
        }
        
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    // MARK: - 6. Detected Connection Status Description
    public var detectedSourceDescription: String {
        if readDesktopPlanUsage() != nil {
            return "🖥️ Claude Desktop 앱 감지됨 (자동 연동)"
        } else if readClaudeCodeQuotaHook() != nil {
            return "⚡ Claude Code 실시간 훅 연동됨"
        } else if readClaudeJsonCache() != nil {
            return "📁 Claude Code 캐시 연동됨"
        } else if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "🔑 Anthropic API 키 연동됨"
        } else if planOverride != "auto" {
            let label = planOverride == "free" ? "Claude Free (무료)" :
                        planOverride == "pro" ? "Claude Pro" :
                        planOverride == "max" ? "Claude Max" :
                        planOverride == "team" ? "Claude Team" : "Claude Enterprise"
            return "⚙️ 수동 지정 모드: \(label)"
        } else {
            return "미연동 ('claude login' 또는 Desktop 앱 필요)"
        }
    }
}
