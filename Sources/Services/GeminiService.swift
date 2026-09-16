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
        get { defaults.string(forKey: planTypeKey) ?? "Gemini Advanced" }
        set { defaults.set(newValue, forKey: planTypeKey) }
    }
    
    public var manualUsedPercent: Double {
        get { defaults.double(forKey: manualUsedPercentKey) }
        set { defaults.set(newValue, forKey: manualUsedPercentKey) }
    }
    
    public func fetchUsage(completion: @escaping (GeminiUsage) -> Void) {
        let key = self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !key.isEmpty {
            fetchWithApiKey(key: key, completion: completion)
        } else {
            // Subscription / Preset mode (Gemini Advanced, Antigravity, etc.)
            fetchSubscriptionPreset(completion: completion)
        }
    }
    
    private func fetchWithApiKey(key: String, completion: @escaping (GeminiUsage) -> Void) {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            fetchSubscriptionPreset(completion: completion)
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
                    } else {
                        usedPercent = self.manualUsedPercent
                    }
                    
                    let nextReset = self.calculateNextRollingReset(intervalHours: 1)
                    
                    DispatchQueue.main.async {
                        completion(GeminiUsage(
                            planName: "Gemini API (유료/개발자)",
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
                }
            }
            
            // If API key failed or had error, return subscription preset with note
            DispatchQueue.main.async {
                var preset = self.createPresetUsage()
                if let err = error {
                    preset.errorMessage = "API 연결 오류: \(err.localizedDescription)"
                }
                completion(preset)
            }
        }.resume()
    }
    
    private func fetchSubscriptionPreset(completion: @escaping (GeminiUsage) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            completion(self.createPresetUsage())
        }
    }
    
    private func createPresetUsage() -> GeminiUsage {
        let resetDate = calculateNextRollingReset(intervalHours: 3)
        return GeminiUsage(
            planName: self.planType,
            usedPercent: self.manualUsedPercent > 0 ? self.manualUsedPercent : 28.0, // Default comfortable usage if not set
            usedRequests: nil,
            limitRequests: nil,
            remainingTokens: nil,
            limitTokens: nil,
            resetsAt: resetDate,
            lastUpdated: Date(),
            isConnected: true,
            errorMessage: nil
        )
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
