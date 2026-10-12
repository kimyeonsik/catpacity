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
        
        // 1순위: 로컬 Claude CLI 또는 ~/.claude.json 로그인 세션 확인
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
                    cliUsage.planName.localizedCaseInsensitiveContains("team")
                )
                
                // 로컬 구독(Team / Pro / Max / Enterprise)이 유효하면 CLI/로컬 구독 정보를 최우선 적용
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
                    // 구독이 없거나 CLI 미로그인 상태인데 API 키가 있다면 API 키 모드로 전환
                    self.fetchWithApiKey(key: key, completion: completionWrapper)
                } else {
                    completionWrapper(cliUsage)
                }
            }
        } else if !key.isEmpty {
            // CLI 및 로컬 설정이 없고 API 키만 있는 경우
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
        if override == "team" {
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
                
                if orgType.contains("max") || rateTier.contains("max") {
                    planName = "Claude Max"
                } else if isTeam {
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
                } else if billing.contains("subscription") || orgType.contains("pro") || rateTier.contains("pro") {
                    planName = "Claude Pro"
                } else {
                    let cleaned = orgType.replacingOccurrences(of: "claude_", with: "").capitalized
                    planName = cleaned.isEmpty ? "Claude Pro" : "Claude \(cleaned)"
                }
                
                return (planName: planName, isConnected: true, errorMessage: nil)
            }
        }
        return nil
    }
    
    private func calculateRecent5HourUsage(planName: String) -> (usedPercent: Double, usedTokens: Int, nextReset: Date) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let projectsDir = home + "/.claude/projects"
        let fiveHoursAgo = Date().addingTimeInterval(-5 * 3600)
        
        var totalTokens = 0
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
                      modDate >= fiveHoursAgo else {
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
                            if d >= fiveHoursAgo {
                                totalTokens += lineTokens
                                if earliestCallTime == nil || d < earliestCallTime! {
                                    earliestCallTime = d
                                }
                            }
                        } else {
                            totalTokens += lineTokens
                        }
                    }
                }
            }
        }
        
        let limitTokens: Double
        if planName.contains("Max") {
            limitTokens = 1_000_000.0
        } else if planName.contains("Enterprise") {
            limitTokens = 1_500_000.0
        } else if planName.contains("Team") {
            limitTokens = 500_000.0
        } else {
            limitTokens = 150_000.0 // Pro default
        }
        
        let calculatedPercent = min(100.0, max(0.0, Double(totalTokens) / limitTokens * 100.0))
        let nextReset: Date
        if let earliest = earliestCallTime {
            nextReset = earliest.addingTimeInterval(5 * 3600)
        } else {
            nextReset = calculateNextRollingReset(intervalHours: 5)
        }
        
        return (usedPercent: calculatedPercent, usedTokens: totalTokens, nextReset: nextReset)
    }
    
    private func checkClaudeCliAuth(completion: @escaping (ClaudeUsage) -> Void) {
        guard let binary = findClaudeBinary() else {
            // CLI 바이너리를 못 찾더라도 로컬 ~/.claude.json에 유효한 세션이 있으면 즉시 연동!
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
                        apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil
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
                    
                    // 타임아웃 발생 시에도 ~/.claude.json 확인
                    if let parsed = self.parseClaudeJsonConfig(), parsed.isConnected {
                        let resetDate = self.calculateNextRollingReset(intervalHours: 5)
                        DispatchQueue.main.async {
                            completion(ClaudeUsage(
                                planName: parsed.planName,
                                usedPercent: 0.0,
                                resetsAt: resetDate,
                                lastUpdated: Date(),
                                isConnected: true,
                                errorMessage: nil,
                                isChecking: false
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
                if let json = self.parseAuthStatusJson(from: outputData),
                   let loggedIn = json["loggedIn"] as? Bool {
                    if !loggedIn {
                        // 만약 ~/.claude.json에 유효한 계정(Team/Pro/Max)이 남아있다면 로컬 설정 기반으로 정상 연동
                        if let parsed = self.parseClaudeJsonConfig(), parsed.isConnected {
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
                                    apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil
                                ))
                            }
                            return
                        }
                        
                        UserDefaults.standard.removeObject(forKey: "catpacity_claude_usage_cache")
                        self.lastKnownValidUsage = nil
                        DispatchQueue.main.async {
                            completion(ClaudeUsage(
                                planName: "구독 없음",
                                usedPercent: 0.0,
                                resetsAt: nil,
                                lastUpdated: Date(),
                                isConnected: false,
                                errorMessage: "Claude 미연동: CLI 로그인 세션 만료 ('claude login' 필요)",
                                isChecking: false
                            ))
                        }
                        return
                    }
                }
                
                // Active login confirmed or local config check
                self.fetchFromLocalClaudeConfig(completion: completion)
            } catch {
                if didComplete { return }
                didComplete = true
                timer.cancel()
                
                if let parsed = self.parseClaudeJsonConfig(), parsed.isConnected {
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
                            apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil
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
                    apiUsedTokens: usageInfo.usedTokens > 0 ? usageInfo.usedTokens : nil
                ))
            }
        } else {
            let resetDate = calculateNextRollingReset(intervalHours: 5)
            DispatchQueue.main.async {
                completion(ClaudeUsage(
                    planName: "Claude Free",
                    usedPercent: 0.0,
                    resetsAt: resetDate,
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
                    
                    let nextReset = self.calculateNextRollingReset(intervalHours: 5)
                    let usedTokens = (limitTok != nil && remainingTok != nil && limitTok! >= remainingTok!) ? (limitTok! - remainingTok!) : nil
                    let estimatedCost = usedTokens != nil ? Double(usedTokens!) * 0.000009 : nil
                    
                    DispatchQueue.main.async {
                        completion(ClaudeUsage(
                            planName: "Anthropic API",
                            usedPercent: min(100.0, max(0.0, usedPercent)),
                            resetsAt: nextReset,
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
    
    private func calculateNextRollingReset(intervalHours: Int) -> Date {
        let now = Date()
        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: now)
        let nextBlockHour = ((currentHour / intervalHours) + 1) * intervalHours
        
        var comp = cal.dateComponents([.year, .month, .day], from: now)
        comp.hour = nextBlockHour
        comp.minute = 0
        comp.second = 0
        
        return cal.date(from: comp) ?? now.addingTimeInterval(TimeInterval(intervalHours * 3600))
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
}
