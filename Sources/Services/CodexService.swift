import Foundation

public class CodexService {
    public static let shared = CodexService()
    
    private var isFetching = false
    public var lastKnownValidUsage: CodexUsage? = CodexUsage.loadCached()
    private let fetchLock = NSLock()
    
    private func setIsFetching(_ value: Bool) {
        fetchLock.lock()
        isFetching = value
        fetchLock.unlock()
    }
    
    private let defaults = UserDefaults.standard
    private let apiKeyKey = "catpacity_codex_api_key"
    
    public var apiKey: String {
        get { defaults.string(forKey: apiKeyKey) ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "" }
        set { defaults.set(newValue, forKey: apiKeyKey) }
    }
    
    public func fetchUsage(completion: @escaping (CodexUsage) -> Void) {
        fetchLock.lock()
        if isFetching {
            fetchLock.unlock()
            if let cached = lastKnownValidUsage {
                completion(cached)
            } else {
                completion(CodexUsage.initial)
            }
            return
        }
        isFetching = true
        fetchLock.unlock()
        
        let key = self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let codexBinary = self?.findCodexBinary()
            guard let binary = codexBinary, FileManager.default.fileExists(atPath: binary) else {
                if !key.isEmpty {
                    self?.fetchWithApiKey(key: key, completion: completion)
                } else {
                    self?.setIsFetching(false)
                    if var cached = self?.lastKnownValidUsage, cached.isConnected {
                        cached.lastUpdated = Date()
                        cached.isChecking = false
                        DispatchQueue.main.async {
                            completion(cached)
                        }
                    } else {
                        DispatchQueue.main.async {
                            var usage = CodexUsage.initial
                            usage.errorMessage = "Codex 미설치: 터미널에서 'npm i -g @openai/codex' 실행 또는 API 키 입력"
                            usage.isChecking = false
                            completion(usage)
                        }
                    }
                }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = ["app-server"]
            process.environment = EnvironmentHelper.makeProcessEnvironment()
            
            let inPipe = Pipe()
            let outPipe = Pipe()
            process.standardInput = inPipe
            process.standardOutput = outPipe
            process.standardError = Pipe() // Silence stderr
            
            var textBuffer = ""
            var hasSentRateRequest = false
            let stateLock = NSLock()
            var didComplete = false
            
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + 15.0)
            
            let finishWith: (CodexUsage) -> Void = { [weak self] usage in
                stateLock.lock()
                guard !didComplete else {
                    stateLock.unlock()
                    return
                }
                didComplete = true
                stateLock.unlock()
                
                timer.cancel()
                outPipe.fileHandleForReading.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
                self?.setIsFetching(false)
                
                var finalUsage = usage
                if finalUsage.isConnected {
                    finalUsage.isChecking = false
                    self?.lastKnownValidUsage = finalUsage
                    finalUsage.saveCached()
                } else if var cached = self?.lastKnownValidUsage, cached.isConnected {
                    // Gracefully preserve cached valid connection on transient blips
                    cached.lastUpdated = Date()
                    cached.isChecking = false
                    finalUsage = cached
                }
                
                if !key.isEmpty {
                    self?.fetchApiCostOnly(key: key) { cost, tokens in
                        finalUsage.apiEstimatedCost = cost
                        finalUsage.apiUsedTokens = tokens
                        DispatchQueue.main.async {
                            completion(finalUsage)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(finalUsage)
                    }
                }
            }
            
            timer.setEventHandler {
                var timeoutUsage = CodexUsage.initial
                timeoutUsage.errorMessage = "요청 시간 초과 (Timeout)"
                timeoutUsage.isChecking = false
                timeoutUsage.isConnected = false
                finishWith(timeoutUsage)
            }
            timer.resume()
            
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                guard let text = String(data: chunk, encoding: .utf8) else { return }
                
                var linesToProcess: [String] = []
                var shouldSendRateReq = false
                
                stateLock.lock()
                if didComplete {
                    stateLock.unlock()
                    return
                }
                textBuffer.append(text)
                
                while let newlineRange = textBuffer.range(of: "\n") {
                    let line = String(textBuffer[..<newlineRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    textBuffer = String(textBuffer[newlineRange.upperBound...])
                    if !line.isEmpty {
                        linesToProcess.append(line)
                    }
                }
                
                for line in linesToProcess {
                    if !hasSentRateRequest && line.contains("\"id\":\"init-1\"") {
                        hasSentRateRequest = true
                        shouldSendRateReq = true
                    }
                }
                stateLock.unlock()
                
                if shouldSendRateReq {
                    let req = "{\"jsonrpc\":\"2.0\",\"id\":\"rate-1\",\"method\":\"account/rateLimits/read\",\"params\":{}}\n"
                    if let data = req.data(using: .utf8) {
                        inPipe.fileHandleForWriting.write(data)
                    }
                }
                
                for line in linesToProcess {
                    if line.contains("\"id\":\"rate-1\"") {
                        let parsed = self?.parseResponse(line) ?? CodexUsage.initial
                        finishWith(parsed)
                        return
                    }
                }
            }
            
            do {
                try process.run()
                let initReq = "{\"jsonrpc\":\"2.0\",\"id\":\"init-1\",\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"catpacity\",\"version\":\"1.0.0\"}}}\n"
                if let data = initReq.data(using: .utf8) {
                    inPipe.fileHandleForWriting.write(data)
                }
            } catch {
                var errUsage = CodexUsage.initial
                errUsage.errorMessage = error.localizedDescription
                errUsage.isChecking = false
                errUsage.isConnected = false
                finishWith(errUsage)
            }
        }
    }
    
    private func findCodexBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.bun/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.codex-runtime/bin/codex"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Dynamic search in PATH via 'which codex'
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["codex"]
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
    
    private func parseResponse(_ jsonString: String) -> CodexUsage {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            var failed = CodexUsage.initial
            failed.isConnected = false
            failed.errorMessage = "Codex 응답 파싱 실패"
            return failed
        }
        
        // 1. Check RPC Error
        if let err = json["error"] as? [String: Any] {
            let msg = err["message"] as? String ?? "인증 실패"
            var failed = CodexUsage.initial
            failed.isConnected = false
            failed.errorMessage = "Codex 오류: \(msg)"
            return failed
        }
        
        // 2. Strictly verify rateLimits and primary quota exist
        guard let result = json["result"] as? [String: Any],
              let rateLimits = result["rateLimits"] as? [String: Any],
              let primary = rateLimits["primary"] as? [String: Any] else {
            var failed = CodexUsage.initial
            failed.isConnected = false
            failed.errorMessage = "Codex 미로그인 (터미널에서 'codex login' 필요)"
            return failed
        }
        
        let ordinaryUsageAllowed = result["ordinaryUsageAllowed"] as? Bool ?? true

        
        let rawPlan = rateLimits["planType"] as? String ?? "pro"
        let planType = "Codex " + rawPlan.capitalized
        
        let usedPercent = Double(primary["usedPercent"] as? Int ?? 0)
        let windowDurationMins = primary["windowDurationMins"] as? Int
        
        var resetsAtDate: Date? = nil
        if let resetsAt = primary["resetsAt"] as? TimeInterval {
            resetsAtDate = Date(timeIntervalSince1970: resetsAt)
        }
        
        let credits = rateLimits["credits"] as? [String: Any]
        let balance = credits?["balance"] as? String
        let hasCredits = credits?["hasCredits"] as? Bool ?? false
        
        var submodels: [SubModelUsage] = []
        if let byLimitId = result["rateLimitsByLimitId"] as? [String: [String: Any]] {
            for (key, dict) in byLimitId {
                let limitName = dict["limitName"] as? String
                let subPrimary = dict["primary"] as? [String: Any]
                let subUsed = Double(subPrimary?["usedPercent"] as? Int ?? 0)
                let subWindow = subPrimary?["windowDurationMins"] as? Int
                var subReset: Date? = nil
                if let resetTs = subPrimary?["resetsAt"] as? TimeInterval {
                    subReset = Date(timeIntervalSince1970: resetTs)
                }
                
                submodels.append(SubModelUsage(
                    limitId: key,
                    limitName: limitName,
                    usedPercent: subUsed,
                    resetsAt: subReset,
                    windowDurationMins: subWindow
                ))
            }
        }
        
        var resetCreditsAvailableCount = 0
        var resetCredits: [RateLimitResetCredit] = []
        if let resetCreditsObj = result["rateLimitResetCredits"] as? [String: Any] {
            resetCreditsAvailableCount = resetCreditsObj["availableCount"] as? Int ?? 0
            if let arr = resetCreditsObj["credits"] as? [[String: Any]] {
                for item in arr {
                    let id = item["id"] as? String ?? UUID().uuidString
                    let resetType = item["resetType"] as? String
                    let status = item["status"] as? String
                    let title = item["title"] as? String
                    let desc = item["description"] as? String
                    var grantedDate: Date? = nil
                    if let ts = item["grantedAt"] as? TimeInterval {
                        grantedDate = Date(timeIntervalSince1970: ts)
                    }
                    var expiresDate: Date? = nil
                    if let ts = item["expiresAt"] as? TimeInterval {
                        expiresDate = Date(timeIntervalSince1970: ts)
                    }
                    resetCredits.append(RateLimitResetCredit(
                        id: id,
                        resetType: resetType,
                        status: status,
                        grantedAt: grantedDate,
                        expiresAt: expiresDate,
                        title: title,
                        description: desc
                    ))
                }
            }
        }
        
        return CodexUsage(
            planType: planType,
            usedPercent: usedPercent,
            resetsAt: resetsAtDate,
            windowDurationMins: windowDurationMins,
            creditsBalance: balance,
            hasCredits: hasCredits,
            ordinaryUsageAllowed: ordinaryUsageAllowed,
            submodels: submodels,
            lastUpdated: Date(),
            isConnected: true,
            errorMessage: nil,
            isChecking: false,
            resetCreditsAvailableCount: resetCreditsAvailableCount,
            resetCredits: resetCredits
        )
    }
    
    public func consumeResetCredit(completion: @escaping (Bool, String?) -> Void) {
        let codexBinary = findCodexBinary()
        guard let binary = codexBinary, FileManager.default.fileExists(atPath: binary) else {
            completion(false, "Codex 바이너리를 찾을 수 없습니다.")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = ["app-server"]
            process.environment = EnvironmentHelper.makeProcessEnvironment()
            
            let inPipe = Pipe()
            let outPipe = Pipe()
            process.standardInput = inPipe
            process.standardOutput = outPipe
            process.standardError = Pipe()
            
            var textBuffer = ""
            var hasSentConsumeRequest = false
            let stateLock = NSLock()
            var didComplete = false
            
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + 15.0)
            
            let finishWith: (Bool, String?) -> Void = { [weak self] success, errMsg in
                stateLock.lock()
                guard !didComplete else {
                    stateLock.unlock()
                    return
                }
                didComplete = true
                stateLock.unlock()
                
                timer.cancel()
                outPipe.fileHandleForReading.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
                
                DispatchQueue.main.async {
                    if success {
                        self?.fetchUsage { _ in }
                    }
                    completion(success, errMsg)
                }
            }
            
            timer.setEventHandler {
                finishWith(false, "요청 시간 초과 (Timeout)")
            }
            timer.resume()
            
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                guard let text = String(data: chunk, encoding: .utf8) else { return }
                
                var linesToProcess: [String] = []
                var shouldSendConsumeReq = false
                
                stateLock.lock()
                if didComplete {
                    stateLock.unlock()
                    return
                }
                textBuffer.append(text)
                
                while let newlineRange = textBuffer.range(of: "\n") {
                    let line = String(textBuffer[..<newlineRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    textBuffer = String(textBuffer[newlineRange.upperBound...])
                    if !line.isEmpty {
                        linesToProcess.append(line)
                    }
                }
                
                for line in linesToProcess {
                    if !hasSentConsumeRequest && line.contains("\"id\":\"init-1\"") {
                        hasSentConsumeRequest = true
                        shouldSendConsumeReq = true
                    }
                }
                stateLock.unlock()
                
                if shouldSendConsumeReq {
                    let idempotencyKey = UUID().uuidString
                    let req = "{\"jsonrpc\":\"2.0\",\"id\":\"consume-1\",\"method\":\"account/rateLimitResetCredit/consume\",\"params\":{\"idempotencyKey\":\"\(idempotencyKey)\"}}\n"
                    if let data = req.data(using: .utf8) {
                        inPipe.fileHandleForWriting.write(data)
                    }
                }
                
                for line in linesToProcess {
                    if line.contains("\"id\":\"consume-1\"") {
                        var success = false
                        var errMsg: String? = nil
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let res = json["result"] as? [String: Any], res["outcome"] as? String == "reset" {
                                success = true
                            } else if let err = json["error"] as? [String: Any] {
                                errMsg = err["message"] as? String ?? "리셋 처리 실패"
                            } else {
                                errMsg = "알 수 없는 응답"
                            }
                        } else {
                            errMsg = "응답 파싱 실패"
                        }
                        
                        finishWith(success, errMsg)
                        return
                    }
                }
            }
            
            do {
                try process.run()
                let initReq = "{\"jsonrpc\":\"2.0\",\"id\":\"init-1\",\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"catpacity\",\"version\":\"1.0.0\"}}}\n"
                if let data = initReq.data(using: .utf8) {
                    inPipe.fileHandleForWriting.write(data)
                }
            } catch {
                finishWith(false, error.localizedDescription)
            }
        }
    }
    
    private func fetchWithApiKey(key: String, completion: @escaping (CodexUsage) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            self.setIsFetching(false)
            DispatchQueue.main.async {
                var usage = CodexUsage.initial
                usage.errorMessage = "잘못된 API 엔드포인트 URL"
                usage.isChecking = false
                usage.isConnected = false
                completion(usage)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.setIsFetching(false)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
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
                    
                    let nextReset = self.calculateNextRollingReset(intervalHours: 3)
                    let usedTok = (limitTok != nil && remainingTok != nil && limitTok! >= remainingTok!) ? (limitTok! - remainingTok!) : nil
                    let estimatedCost = usedTok != nil ? Double(usedTok!) * 0.000005 : nil
                    
                    let usage = CodexUsage(
                        planType: "OpenAI API",
                        usedPercent: min(100.0, max(0.0, usedPercent)),
                        resetsAt: nextReset,
                        lastUpdated: Date(),
                        isConnected: true,
                        errorMessage: nil,
                        isChecking: false,
                        resetCreditsAvailableCount: 0,
                        resetCredits: [],
                        apiEstimatedCost: estimatedCost,
                        apiUsedTokens: usedTok
                    )
                    self.lastKnownValidUsage = usage
                    usage.saveCached()
                    
                    DispatchQueue.main.async {
                        completion(usage)
                    }
                    return
                } else {
                    DispatchQueue.main.async {
                        completion(CodexUsage(
                            planType: "API 오류",
                            usedPercent: 0.0,
                            resetsAt: nil,
                            lastUpdated: Date(),
                            isConnected: false,
                            errorMessage: "OpenAI API 인증 실패 (HTTP \(httpResponse.statusCode))",
                            isChecking: false,
                            resetCreditsAvailableCount: 0,
                            resetCredits: []
                        ))
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                completion(CodexUsage(
                    planType: "연결 오류",
                    usedPercent: 0.0,
                    resetsAt: nil,
                    lastUpdated: Date(),
                    isConnected: false,
                    errorMessage: "OpenAI 통신 실패: \(error?.localizedDescription ?? "알 수 없는 오류")",
                    isChecking: false,
                    resetCreditsAvailableCount: 0,
                    resetCredits: []
                ))
            }
        }.resume()
    }
    
    private func fetchApiCostOnly(key: String, completion: @escaping (Double?, Int?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            completion(nil, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6.0
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let remainingTok = httpResponse.value(forHTTPHeaderField: "x-ratelimit-remaining-tokens").flatMap { Int($0) }
                let limitTok = httpResponse.value(forHTTPHeaderField: "x-ratelimit-limit-tokens").flatMap { Int($0) }
                let usedTok = (limitTok != nil && remainingTok != nil && limitTok! >= remainingTok!) ? (limitTok! - remainingTok!) : nil
                let cost = usedTok != nil ? Double(usedTok!) * 0.000005 : nil
                DispatchQueue.main.async {
                    completion(cost, usedTok)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
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
