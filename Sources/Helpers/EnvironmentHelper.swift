import Foundation

public enum EnvironmentHelper {
    public static func makeProcessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        env["HOME"] = home
        env["USER"] = NSUserName()
        
        let customPaths = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        
        let existingPath = env["PATH"] ?? ""
        let existingParts = existingPath.components(separatedBy: ":")
        var combinedParts = customPaths
        for p in existingParts where !combinedParts.contains(p) && !p.isEmpty {
            combinedParts.append(p)
        }
        env["PATH"] = combinedParts.joined(separator: ":")
        env["DEVELOPER_DIR"] = "/Library/Developer/CommandLineTools"
        return env
    }
}
