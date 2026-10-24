import Foundation
import AppKit

public class UpdateCheckerService {
    public static let shared = UpdateCheckerService()
    
    private let repo = "kimyeonsik/catpacity"
    
    public var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0"
    }
    
    public func checkForUpdates(manual: Bool = false, completion: @escaping (_ updateAvailable: Bool, _ latestTag: String, _ releaseUrl: String, _ errorMsg: String?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=100") else {
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
            
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let data = data,
                  let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let json = Self.catpacityRelease(from: releases),
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

    /// CatWorks shares this repository's Releases, but is a separate product.
    /// Never offer its tag or its DMG to Catpacity's own updater.
    static func catpacityRelease(from releases: [[String: Any]]) -> [String: Any]? {
        releases.filter { release in
            guard release["draft"] as? Bool != true, release["prerelease"] as? Bool != true,
                  let tag = release["tag_name"] as? String,
                  tag.range(of: "^[vV]?[0-9]+(?:\\.[0-9]+){1,3}$", options: .regularExpression) != nil,
                  let url = release["html_url"] as? String,
                  url == "https://github.com/kimyeonsik/catpacity/releases/tag/\(tag)",
                  let assets = release["assets"] as? [[String: Any]] else { return false }
            return assets.contains { asset in
                guard let name = asset["name"] as? String else { return false }
                return name == "Catpacity-macOS.zip" || name == "Catpacity-\(tag)-macOS.zip"
            }
        }.sorted {
            shared.compareVersions(latest: $0["tag_name"] as! String, current: $1["tag_name"] as! String)
        }.first
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
