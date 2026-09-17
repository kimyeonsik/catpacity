import Foundation
import AppKit

public class UpdateCheckerService {
    public static let shared = UpdateCheckerService()
    
    private let repo = "kimyeonsik/catpacity"
    
    public var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0"
    }
    
    public func checkForUpdates(manual: Bool = false, completion: @escaping (_ updateAvailable: Bool, _ latestTag: String, _ releaseUrl: String, _ errorMsg: String?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            completion(false, "", "", "유효하지 않은 URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6.0
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Catpacity-macOS", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "", "", error.localizedDescription)
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let releaseUrl = json["html_url"] as? String else {
                DispatchQueue.main.async {
                    completion(false, "", "", "릴리즈 정보 파싱 실패")
                }
                return
            }
            
            let isNewer = self.compareVersions(latest: tagName, current: self.currentVersion)
            
            DispatchQueue.main.async {
                if isNewer {
                    NotificationService.shared.sendUpdateNotification(version: tagName, releaseUrl: releaseUrl)
                }
                completion(isNewer, tagName, releaseUrl, nil)
            }
        }.resume()
    }
    
    public func compareVersions(latest: String, current: String) -> Bool {
        let cleanLatest = latest.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let cleanCurrent = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        
        let latestParts = cleanLatest.split(separator: ".").compactMap { Int($0) }
        let currentParts = cleanCurrent.split(separator: ".").compactMap { Int($0) }
        
        let maxLen = max(latestParts.count, currentParts.count)
        for i in 0..<maxLen {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}
