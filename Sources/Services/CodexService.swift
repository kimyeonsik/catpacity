import Foundation

public class CodexService {
    public static let shared = CodexService()
    
    private var isFetching = false
    public var lastKnownValidUsage: CodexUsage? = CodexUsage.loadCached()
    
    public func fetchUsage(completion: @escaping (CodexUsage) -> Void) {
        if isFetching {
            if let cached = lastKnownValidUsage {
                completion(cached)
            }
            return
        }
        isFetching = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { self?.isFetching = false }
            
            let codexBinary = self?.findCodexBinary()
            guard let binary = codexBinary, FileManager.default.fileExists(atPath: binary) else {
                DispatchQueue.main.async {
                    var usage = CodexUsage.initial
                    usage.errorMessage = "Codex 미설치: 터미널에서 'npm i -g @openai/codex' 실행"
                    usage.isChecking = false
                    completion(usage)
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
            
            var receivedData = Data()
            var didComplete = false
            
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + 8.0)
            timer.setEventHandler {
                if !didComplete {
                    didComplete = true
                    process.terminate()
                    if var cached = self?.lastKnownValidUsage, cached.isConnected {
                        cached.lastUpdated = Date()
                        cached.isChecking = false
                        DispatchQueue.main.async {
                            completion(cached)
                        }
                    } else {
                        DispatchQueue.main.async {
                            var usage = CodexUsage.initial
                            usage.errorMessage = "요청 시간 초과 (Timeout)"
                            usage.isChecking = false
                            completion(usage)
                        }
                    }
                }
            }
            timer.resume()
            
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                receivedData.append(chunk)
                
                if let string = String(data: receivedData, encoding: .utf8) {
                    let lines = string.components(separatedBy: "\n")
                    for line in lines {
                        if line.contains("\"id\":\"rate-1\"") {
                            timer.cancel()
                            if !didComplete {
                                didComplete = true
                                outPipe.fileHandleForReading.readabilityHandler = nil
                                process.terminate()
                                
                                var usage = self?.parseResponse(line) ?? CodexUsage.initial
                                if usage.isConnected {
                                    usage.isChecking = false
                                    self?.lastKnownValidUsage = usage
                                    usage.saveCached()
                                }
                                DispatchQueue.main.async {
                                    completion(usage)
                                }
                            }
                            return
                        } else if line.contains("\"id\":\"init-1\"") {
                            let req = "{\"jsonrpc\":\"2.0\",\"id\":\"rate-1\",\"method\":\"account/rateLimits/read\",\"params\":{}}\n"
                            if let data = req.data(using: .utf8) {
                                inPipe.fileHandleForWriting.write(data)
                            }
                        }
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
                timer.cancel()
                if !didComplete {
                    didComplete = true
                    if var cached = self?.lastKnownValidUsage, cached.isConnected {
                        cached.lastUpdated = Date()
                        cached.isChecking = false
                        DispatchQueue.main.async {
                            completion(cached)
                        }
                    } else {
                        DispatchQueue.main.async {
                            var usage = CodexUsage.initial
                            usage.errorMessage = error.localizedDescription
                            usage.isChecking = false
                            completion(usage)
                        }
                    }
                }
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
            
            var receivedData = Data()
            var didComplete = false
            
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer.schedule(deadline: .now() + 8.0)
            timer.setEventHandler {
                if !didComplete {
                    didComplete = true
                    process.terminate()
                    DispatchQueue.main.async {
                        completion(false, "요청 시간 초과")
                    }
                }
            }
            timer.resume()
            
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                receivedData.append(chunk)
                
                if let string = String(data: receivedData, encoding: .utf8) {
                    let lines = string.components(separatedBy: "\n")
                    for line in lines {
                        if line.contains("\"id\":\"consume-1\"") {
                            timer.cancel()
                            if !didComplete {
                                didComplete = true
                                outPipe.fileHandleForReading.readabilityHandler = nil
                                process.terminate()
                                
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
                                
                                DispatchQueue.main.async {
                                    if success {
                                        self?.fetchUsage { _ in }
                                    }
                                    completion(success, errMsg)
                                }
                            }
                            return
                        } else if line.contains("\"id\":\"init-1\"") {
                            let idempotencyKey = UUID().uuidString
                            let req = "{\"jsonrpc\":\"2.0\",\"id\":\"consume-1\",\"method\":\"account/rateLimitResetCredit/consume\",\"params\":{\"idempotencyKey\":\"\(idempotencyKey)\"}}\n"
                            if let data = req.data(using: .utf8) {
                                inPipe.fileHandleForWriting.write(data)
                            }
                        }
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
                timer.cancel()
                if !didComplete {
                    didComplete = true
                    DispatchQueue.main.async {
                        completion(false, error.localizedDescription)
                    }
                }
            }
        }
    }
}
