import Foundation

public enum EnvironmentHelper {
    public static func makeProcessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        env["HOME"] = home
        env["USER"] = NSUserName()
        
        var customPaths = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(home)/.bun/bin",
            "\(home)/.npm-global/bin",
            "\(home)/Library/pnpm",
            "\(home)/.local/share/pnpm",
            "\(home)/.yarn/bin",
            "\(home)/.volta/bin",
            "\(home)/.asdf/shims",
            "\(home)/.local/share/mise/shims",
            "\(home)/.local/share/fnm/current/bin",
            "\(home)/Library/Application Support/fnm/current/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        
        // Scan for nvm node versions if present
        let nvmNodeDir = "\(home)/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmNodeDir) {
            for v in versions.sorted().reversed() {
                let binPath = "\(nvmNodeDir)/\(v)/bin"
                if FileManager.default.fileExists(atPath: binPath) {
                    customPaths.insert(binPath, at: 0)
                }
            }
        }
        
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
