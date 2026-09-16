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
            fetchFromLocalClaudeConfig(completion: completion)
        }
    }
    
    private func fetchFromLocalClaudeConfig(completion: @escaping (ClaudeUsage) -> Void) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeJsonPath = home.appendingPathComponent(".claude.json").path
        
        var planName = "Claude Pro"
        var isConnected = true
        
        if let data = FileManager.default.contents(atPath: claudeJsonPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let oauth = json["oauthAccount"] as? [String: Any] {
                if let tier = oauth["rateLimitTier"] as? String, tier.contains("max") {
                    planName = "Claude Max"
                } else if let billing = oauth["billingType"] as? String, billing.contains("subscription") {
                    planName = "Claude Pro"
                }
                isConnected = true
            }
        }
        
        let resetDate = calculateNextRollingReset(intervalHours: 5)
        
        DispatchQueue.main.async {
            completion(ClaudeUsage(
                planName: planName,
                usedPercent: 0.0, // 100% capacity available
                resetsAt: resetDate,
                lastUpdated: Date(),
                isConnected: isConnected,
                errorMessage: nil
            ))
        }
    }
    
    private func fetchWithApiKey(key: String, completion: @escaping (ClaudeUsage) -> Void) {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            fetchFromLocalClaudeConfig(completion: completion)
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
            
            self.fetchFromLocalClaudeConfig(completion: completion)
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
