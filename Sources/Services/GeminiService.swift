import Foundation

public class GeminiService {
    public static let shared = GeminiService()
    
    private let defaults = UserDefaults.standard
    private let apiKeyKey = "catpacity_gemini_api_key"
    private let planTypeKey = "catpacity_gemini_plan_type"
    
    public var apiKey: String {
        get { defaults.string(forKey: apiKeyKey) ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "" }
        set { defaults.set(newValue, forKey: apiKeyKey) }
    }
    
    public var planType: String {
        get { defaults.string(forKey: planTypeKey) ?? "Gemini" }
        set { defaults.set(newValue, forKey: planTypeKey) }
    }
    
    public func fetchUsage(completion: @escaping (GeminiUsage) -> Void) {
        let key = self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !key.isEmpty {
            fetchWithApiKey(key: key, completion: completion)
        } else if let agyBinary = findAgyBinary() {
            fetchWithAgyCli(binary: agyBinary, completion: completion)
        } else {
            checkLocalGoogleCli(completion: completion)
        }
    }
    
    private func findAgyBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/agy",
            "/opt/homebrew/bin/agy",
            "/usr/local/bin/agy",
            "/usr/bin/agy",
            "\(home)/.gemini/antigravity-cli/bin/agy"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.components(separatedBy: ":") {
                let candidate = (dir as NSString).appendingPathComponent("agy")
                if FileManager.default.fileExists(atPath: candidate) {
                    return candidate
                }
            }
        }
        return nil
    }
    
    private func fetchWithAgyCli(binary: String, completion: @escaping (GeminiUsage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = ["-p", "/quota"]
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
                    self.checkLocalGoogleCli(completion: completion)
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
                
                guard let output = String(data: outputData, encoding: .utf8), !output.isEmpty else {
                    self.checkLocalGoogleCli(completion: completion)
                    return
                }
                
                self.parseAgyQuotaOutput(output: output, completion: completion)
            } catch {
                if didComplete { return }
                didComplete = true
                timer.cancel()
                self.checkLocalGoogleCli(completion: completion)
            }
        }
    }
    
    private func parseAgyQuotaOutput(output: String, completion: @escaping (GeminiUsage) -> Void) {
        let isoFormatter = ISO8601DateFormatter()
        
        var fiveHourRemaining: Double? = nil
        var fiveHourResetDate: Date? = nil
        var weeklyRemaining: Double? = nil
        var weeklyResetDate: Date? = nil
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let parts: [String]
            if trimmed.contains("\t") {
                parts = trimmed.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            } else {
                parts = trimmed.components(separatedBy: "  ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
            guard parts.count >= 4 else { continue }
            
            let modelName = parts[0]
            let limitType = parts[1]
            let pctString = parts[2].replacingOccurrences(of: "%", with: "")
            let dateString = parts[3]
            
            guard modelName.lowercased().contains("gemini") else { continue }
            
            let remainingPct = Double(pctString)
            let parsedDate = isoFormatter.date(from: dateString)
            
            if limitType.lowercased().contains("five hour") {
                fiveHourRemaining = remainingPct
                fiveHourResetDate = parsedDate
            } else if limitType.lowercased().contains("weekly") {
                weeklyRemaining = remainingPct
                weeklyResetDate = parsedDate
            }
        }
        
        // If no Gemini quota lines were parsed, fallback
        guard fiveHourRemaining != nil || weeklyRemaining != nil else {
            checkLocalGoogleCli(completion: completion)
            return
        }
        
        // Active account email detection
        let home = FileManager.default.homeDirectoryForCurrentUser
        let accountsPath = home.appendingPathComponent(".gemini/google_accounts.json").path
        var activeAccount: String? = nil
        if let data = FileManager.default.contents(atPath: accountsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let active = json["active"] as? String, !active.isEmpty {
            activeAccount = active
        }
        
        let planLabel: String
        if let email = activeAccount {
            planLabel = "Gemini (\(email))"
        } else {
            planLabel = "Gemini (Antigravity)"
        }
        
        // Prioritize the short-term 5-hour limit for the primary progress bar
        let primaryRemaining = fiveHourRemaining ?? weeklyRemaining ?? 100.0
        let primaryUsed = max(0.0, min(100.0, 100.0 - primaryRemaining))
        let primaryReset = fiveHourResetDate ?? weeklyResetDate
        
        DispatchQueue.main.async {
            completion(GeminiUsage(
                planName: planLabel,
                usedPercent: primaryUsed,
                usedRequests: nil,
                limitRequests: nil,
                remainingTokens: nil,
                limitTokens: nil,
                resetsAt: primaryReset,
                lastUpdated: Date(),
                isConnected: true,
                errorMessage: nil,
                weeklyRemainingPercent: weeklyRemaining,
                weeklyResetsAt: weeklyResetDate
            ))
        }
    }
    
    private func checkLocalGoogleCli(completion: @escaping (GeminiUsage) -> Void) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let accountsPath = home.appendingPathComponent(".gemini/google_accounts.json").path
        
        var activeAccount: String? = nil
        if let data = FileManager.default.contents(atPath: accountsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let active = json["active"] as? String, !active.isEmpty {
            activeAccount = active
        }
        
        if let email = activeAccount {
            // Local login found but Antigravity CLI telemetry could not be fetched
            DispatchQueue.main.async {
                completion(GeminiUsage(
                    planName: "Gemini (\(email))",
                    usedPercent: 0.0,
                    usedRequests: nil,
                    limitRequests: nil,
                    remainingTokens: nil,
                    limitTokens: nil,
                    resetsAt: nil,
                    lastUpdated: Date(),
                    isConnected: false,
                    errorMessage: "할당량 확인 불가 (Antigravity CLI 또는 API 키 필요)",
                    weeklyRemainingPercent: nil,
                    weeklyResetsAt: nil
                ))
            }
        } else {
            // Neither API key nor active CLI session exists
            DispatchQueue.main.async {
                completion(GeminiUsage(
                    planName: "미연동",
                    usedPercent: 0.0,
                    usedRequests: nil,
                    limitRequests: nil,
                    remainingTokens: nil,
                    limitTokens: nil,
                    resetsAt: nil,
                    lastUpdated: Date(),
                    isConnected: false,
                    errorMessage: "Gemini 미연동 (Antigravity 또는 API 키 필요)",
                    weeklyRemainingPercent: nil,
                    weeklyResetsAt: nil
                ))
            }
        }
    }
    
    private func fetchWithApiKey(key: String, completion: @escaping (GeminiUsage) -> Void) {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            checkLocalGoogleCli(completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Extract rate limit headers if present
                    let remainingReq = httpResponse.value(forHTTPHeaderField: "x-ratelimit-remaining-requests").flatMap { Int($0) }
                    let limitReq = httpResponse.value(forHTTPHeaderField: "x-ratelimit-limit-requests").flatMap { Int($0) }
                    let remainingTok = httpResponse.value(forHTTPHeaderField: "x-ratelimit-remaining-tokens").flatMap { Int($0) }
                    let limitTok = httpResponse.value(forHTTPHeaderField: "x-ratelimit-limit-tokens").flatMap { Int($0) }
                    
                    var usedPercent: Double = 0.0
                    if let rem = remainingTok, let lim = limitTok, lim > 0 {
                        usedPercent = Double(lim - rem) / Double(lim) * 100.0
                    } else if let rem = remainingReq, let lim = limitReq, lim > 0 {
                        usedPercent = Double(lim - rem) / Double(lim) * 100.0
                    }
                    
                    let nextReset = self.calculateNextRollingReset(intervalHours: 1)
                    
                    DispatchQueue.main.async {
                        completion(GeminiUsage(
                            planName: "Gemini API",
                            usedPercent: min(100.0, max(0.0, usedPercent)),
                            usedRequests: (limitReq != nil && remainingReq != nil) ? (limitReq! - remainingReq!) : nil,
                            limitRequests: limitReq,
                            remainingTokens: remainingTok,
                            limitTokens: limitTok,
                            resetsAt: nextReset,
                            lastUpdated: Date(),
                            isConnected: true,
                            errorMessage: nil,
                            weeklyRemainingPercent: nil,
                            weeklyResetsAt: nil
                        ))
                    }
                    return
                } else {
                    DispatchQueue.main.async {
                        completion(GeminiUsage(
                            planName: "API 오류",
                            usedPercent: 0.0,
                            usedRequests: nil,
                            limitRequests: nil,
                            remainingTokens: nil,
                            limitTokens: nil,
                            resetsAt: nil,
                            lastUpdated: Date(),
                            isConnected: false,
                            errorMessage: "Gemini API 인증 실패 (HTTP \(httpResponse.statusCode))",
                            weeklyRemainingPercent: nil,
                            weeklyResetsAt: nil
                        ))
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                completion(GeminiUsage(
                    planName: "연결 오류",
                    usedPercent: 0.0,
                    usedRequests: nil,
                    limitRequests: nil,
                    remainingTokens: nil,
                    limitTokens: nil,
                    resetsAt: nil,
                    lastUpdated: Date(),
                    isConnected: false,
                    errorMessage: "Gemini 통신 실패: \(error?.localizedDescription ?? "알 수 없는 오류")",
                    weeklyRemainingPercent: nil,
                    weeklyResetsAt: nil
                ))
            }
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
