import AppKit

// Linked only by run-action-tests.sh. These replace external account, notification,
// installation and login-item boundaries; AppState and all views are production sources.
final class CodexService {
    static let shared = CodexService()
    var apiKey = ""
    var hasCliInstalled = true
    var detectedSourceDescription = "test boundary"
    var usage = CodexUsage.initial
    var fetches = 0
    var login: (() -> Void)?
    var installs = 0
    func fetchUsage(completion: @escaping (CodexUsage) -> Void) { fetches += 1; completion(usage) }
    func launchTerminalLogin(completion: (() -> Void)? = nil) { login = completion }
    func launchTerminalInstallAndLogin(completion: (() -> Void)? = nil) { installs += 1; login = completion }
    func consumeResetCredit(completion: (Bool, String?) -> Void) { preconditionFailure("No credits may be consumed") }
}
final class GeminiService {
    static let shared = GeminiService()
    var apiKey = ""
    var hasAgyInstalled = true
    var detectedSourceDescription = "test boundary"
    var usage = GeminiUsage.initial
    var fetches = 0
    var login: (() -> Void)?
    func fetchUsage(completion: @escaping (GeminiUsage) -> Void) { fetches += 1; completion(usage) }
    func launchTerminalLogin(completion: (() -> Void)? = nil) { login = completion }
    func openAiStudioWeb() { preconditionFailure("No external browser action expected") }
}
final class ClaudeService {
    static let shared = ClaudeService()
    var apiKey = ""
    var planOverride = "auto"
    var hasCliInstalled = true
    var detectedSourceDescription = "test boundary"
    var usage = ClaudeUsage.initial
    var fetches = 0
    var login: (() -> Void)?
    var installs = 0
    func fetchUsage(completion: @escaping (ClaudeUsage) -> Void) { fetches += 1; completion(usage) }
    func launchTerminalLogin(completion: (() -> Void)? = nil) { login = completion }
    func launchTerminalInstallAndLogin(completion: (() -> Void)? = nil) { installs += 1; login = completion }
    func setupClaudeCodeIntegration() -> (success: Bool, message: String) { preconditionFailure("No personal hook changes") }
}
final class NotificationService {
    static let shared = NotificationService()
    var observedPercent: Double?
    var updates: [String] = []
    func checkAndNotify(usedPercent: Double) { observedPercent = usedPercent }
    func sendUpdateNotification(version: String, releaseUrl: String) { updates.append(version) }
}
final class SelfUpdateService {
    static let shared = SelfUpdateService()
    var tags: [String] = []
    var progress: ((String) -> Void)?
    var failure: ((String) -> Void)?
    func performUpdate(tag: String, onProgress: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        tags.append(tag); progress = onProgress; failure = onError
    }
}
enum LaunchAtLoginHelper {
    static var isEnabled: Bool {
        get { false }
        set { preconditionFailure("No login-item changes") }
    }
}
