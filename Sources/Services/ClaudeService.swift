import Foundation

public class ClaudeService {
    public static let shared = ClaudeService()
    
    private let defaults = UserDefaults.standard
    private let apiKeyKey = "catpacity_claude_api_key"
    
    public var apiKey: String {
        get { defaults.string(forKey: apiKeyKey) ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "" }
        set { defaults.set(newValue, forKey: apiKeyKey) }
    }
    
    public func fetchUsage(completion: @escaping (ClaudeUsage) -> Void) {
        let key = self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !key.isEmpty {
            fetchWithApiKey(key: key, completion: completion)
        } else {
            checkClaudeCliAuth(completion: completion)
        }
    }
    
    private func findClaudeBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude"
        ]
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
        return nil
    }
    
    private func checkClaudeCliAuth(completion: @escaping (ClaudeUsage) -> Void) {
        guard let binary = findClaudeBinary() else {
            DispatchQueue.main.async {
                completion(ClaudeUsage(
                    planName: "미연동",
                    usedPercent: 0.0,
                    resetsAt: nil,
                    lastUpdated: Date(),
                    isConnected: false,
                    errorMessage: "Claude 미연동 (CLI 미설치 또는 API 키 필요)"
                ))
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
            timer.schedule(deadline: .now() + 6.0)
            timer.setEventHandler {
                if !didComplete {
                    didComplete = true
                    process.terminate()
                    DispatchQueue.main.async {
                        completion(ClaudeUsage(
                            planName: "미연동",
                            usedPercent: 0.0,
                            resetsAt: nil,
                            lastUpdated: Date(),
                            isConnected: false,
                            errorMessage: "Claude 인증 확인 시간 초과"
                        ))
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
                
                var isLoggedIn = false
                if let json = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
                   let loggedIn = json["loggedIn"] as? Bool {
                    isLoggedIn = loggedIn
                }
                
                if !isLoggedIn {
                    DispatchQueue.main.async {
                        completion(ClaudeUsage(
                            planName: "구독 없음",
                            usedPercent: 0.0,
                            resetsAt: nil,
                            lastUpdated: Date(),
                            isConnected: false,
                            errorMessage: "Claude 미연동 (로그아웃됨 또는 구독 없음)"
                        ))
                    }
                    return
                }
                
                // Active login confirmed, inspect ~/.claude.json for plan details
                self.fetchFromLocalClaudeConfig(completion: completion)
            } catch {
                if didComplete { return }
                didComplete = true
                timer.cancel()
                DispatchQueue.main.async {
                    completion(ClaudeUsage(
                        planName: "미연동",
                        usedPercent: 0.0,
                        resetsAt: nil,
                        lastUpdated: Date(),
                        isConnected: false,
                        errorMessage: "Claude 인증 확인 오류: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }
    
    private func fetchFromLocalClaudeConfig(completion: @escaping (ClaudeUsage) -> Void) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeJsonPath = home.appendingPathComponent(".claude.json").path
        
        var planName = "Claude Free"
        
        if let data = FileManager.default.contents(atPath: claudeJsonPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let oauth = json["oauthAccount"] as? [String: Any] {
                let orgType = (oauth["organizationType"] as? String ?? "").lowercased()
                let rateTier = (oauth["organizationRateLimitTier"] as? String ?? "").lowercased()
                let billing = (oauth["billingType"] as? String ?? "").lowercased()
                
                if orgType.contains("max") || rateTier.contains("max") {
                    planName = "Claude Max"
                } else if billing.contains("subscription") || orgType.contains("pro") {
                    planName = "Claude Pro"
                } else {
                    planName = "Claude Free"
                }
            }
        }
        
        let resetDate = calculateNextRollingReset(intervalHours: 5)
        
        DispatchQueue.main.async {
            completion(ClaudeUsage(
                planName: planName,
                usedPercent: 0.0, // 100% capacity available
                resetsAt: resetDate,
                lastUpdated: Date(),
                isConnected: true,
                errorMessage: nil
            ))
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
                    DispatchQueue.main.async {
                        completion(ClaudeUsage(
                            planName: "Anthropic API",
                            usedPercent: min(100.0, max(0.0, usedPercent)),
                            resetsAt: nextReset,
                            lastUpdated: Date(),
                            isConnected: true,
                            errorMessage: nil
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
}
