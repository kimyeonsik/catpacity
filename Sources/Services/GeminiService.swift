import Foundation

public class GeminiService {
    public static let shared = GeminiService()
    
    private let defaults = UserDefaults.standard
    private let apiKeyKey = "catpacity_gemini_api_key"
    private let planTypeKey = "catpacity_gemini_plan_type"
    private let manualUsedPercentKey = "catpacity_gemini_manual_used_percent"
    private let lastResetTimestampKey = "catpacity_gemini_last_reset_time"
    
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
        } else {
            checkLocalGoogleCli(completion: completion)
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
            // Local Gemini CLI active login found
            let resetDate = calculateNextRollingReset(intervalHours: 3)
            DispatchQueue.main.async {
                completion(GeminiUsage(
                    planName: "Gemini (\(email))",
                    usedPercent: 0.0,
                    usedRequests: nil,
                    limitRequests: nil,
                    remainingTokens: nil,
                    limitTokens: nil,
                    resetsAt: resetDate,
                    lastUpdated: Date(),
                    isConnected: true,
                    errorMessage: nil
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
                    errorMessage: "Gemini 미연동 (API 키 또는 CLI 로그인 필요)"
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
                            errorMessage: nil
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
                            errorMessage: "Gemini API 인증 실패 (HTTP \(httpResponse.statusCode))"
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
                    errorMessage: "Gemini 통신 실패: \(error?.localizedDescription ?? "알 수 없는 오류")"
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
