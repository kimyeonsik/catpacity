import Foundation

public class CodexService {
    public static let shared = CodexService()
    
    private var isFetching = false
    
    public func fetchUsage(completion: @escaping (CodexUsage) -> Void) {
        if isFetching { return }
        isFetching = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { self?.isFetching = false }
            
            let codexBinary = self?.findCodexBinary()
            guard let binary = codexBinary, FileManager.default.fileExists(atPath: binary) else {
                DispatchQueue.main.async {
                    var usage = CodexUsage.initial
                    usage.errorMessage = "Codex 미설치: 터미널에서 'npm i -g @openai/codex' 실행"
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
                    DispatchQueue.main.async {
                        var usage = CodexUsage.initial
                        usage.errorMessage = "요청 시간 초과 (Timeout)"
                        completion(usage)
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
                                
                                let usage = self?.parseResponse(line) ?? CodexUsage.initial
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
                    DispatchQueue.main.async {
                        var usage = CodexUsage.initial
                        usage.errorMessage = error.localizedDescription
                        completion(usage)
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
        if !ordinaryUsageAllowed {
            var failed = CodexUsage.initial
            failed.isConnected = false
            failed.errorMessage = "Codex 계정 사용 제한됨 (한도 초과)"
            return failed
        }
        
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
            errorMessage: nil
        )
    }
}
