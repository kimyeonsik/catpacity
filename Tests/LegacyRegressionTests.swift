import AppKit
import Foundation

private final class UpdateFixtureProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var failure = false
    nonisolated(unsafe) static var calls = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        precondition(request.url?.absoluteString == "https://api.github.com/repos/kimyeonsik/catpacity/releases?per_page=100")
        precondition(request.httpMethod == "GET")
        Self.calls += 1
        if Self.failure { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
private struct LegacyRegressionTests {
    @MainActor static func main() async throws {
        // The test executable has no product bundle identifier and never reads account services.
        UserDefaults.standard.setVolatileDomain([
            "catpacity_codex_usage_cache": Data(), "catpacity_claude_usage_cache": Data(),
            "catpacity_gemini_usage_cache": Data(), "catpacity_last_notified_update_version": "v99.0.0"
        ], forName: UserDefaults.argumentDomain)
        var codex = CodexUsage.initial
        precondition(!codex.isConnected)
        if case .disconnected = codex.currentMode() {} else { preconditionFailure("Codex login state") }
        codex.isConnected = true; codex.usedPercent = 40
        precondition(codex.remainingPercent == 60)
        if case .subscriptionActive(let remaining, _, _) = codex.currentMode() { precondition(remaining == 60) }
        else { preconditionFailure("Connected quota mode") }
        codex.usedPercent = 100
        if case .subscriptionExhausted = codex.currentMode() {} else { preconditionFailure("Exhausted quota mode") }
        var claude = ClaudeUsage.initial
        claude.isConnected = true; claude.planName = "Claude Free"; claude.usedPercent = 100
        precondition(!claude.isMeasurable)
        codex.usedPercent = 40
        let usage = OverallUsage(codex: codex, gemini: GeminiUsage.initial, claude: claude)
        precondition(usage.minRemainingPercent == 60, "Unmeasurable free plan cannot change energy")
        var oldCodex = try JSONSerialization.jsonObject(with: JSONEncoder().encode(codex)) as! [String: Any]
        oldCodex.removeValue(forKey: "resetCreditsAvailableCount")
        oldCodex.removeValue(forKey: "resetCredits")
        oldCodex.removeValue(forKey: "isChecking")
        let restored = try JSONDecoder().decode(CodexUsage.self, from: JSONSerialization.data(withJSONObject: oldCodex))
        precondition(restored.usedPercent == 40 && restored.resetCreditsAvailableCount == 0 && !restored.isChecking,
                     "Old cached quota data remains decodable")
        let checker = UpdateCheckerService.shared
        precondition(checker.compareVersions(latest: "v1.10.0", current: "1.9.9"))
        precondition(!checker.compareVersions(latest: "v1.4.15", current: "1.4.15"))
        let releases: [[String: Any]] = [
            ["tag_name": "catworks-v99.0.0", "html_url": "https://github.com/kimyeonsik/catpacity/releases/tag/catworks-v99.0.0", "assets": [["name": "CatWorks-99-universal.dmg"]]],
            ["tag_name": "v100.0.0", "html_url": "https://github.com/kimyeonsik/catpacity/releases/tag/v100.0.0", "assets": [["name": "CatWorks-100-universal.dmg"]]],
            ["tag_name": "v1.4.16", "html_url": "https://github.com/kimyeonsik/catpacity/releases/tag/v1.4.16", "prerelease": true, "assets": [["name": "Catpacity-macOS.zip"]]],
            ["tag_name": "v1.4.15", "html_url": "https://github.com/kimyeonsik/catpacity/releases/tag/v1.4.15", "assets": [["name": "Catpacity-macOS.zip"]]]
        ]
        precondition(UpdateCheckerService.catpacityRelease(from: releases)?["tag_name"] as? String == "v1.4.15", "Shared Releases must never update Catpacity with CatWorks or prerelease assets")
        URLProtocol.registerClass(UpdateFixtureProtocol.self)
        for (body, failure, expectedAvailable, expectedError) in [
            ("[{\"tag_name\":\"v99.0.0\",\"html_url\":\"https://github.com/kimyeonsik/catpacity/releases/tag/v99.0.0\",\"assets\":[{\"name\":\"Catpacity-macOS.zip\"}]}]", false, true, false),
            ("[{\"tag_name\":\"v0.0.1\",\"html_url\":\"https://github.com/kimyeonsik/catpacity/releases/tag/v0.0.1\",\"assets\":[{\"name\":\"Catpacity-macOS.zip\"}]}]", false, false, false),
            ("{}", false, false, true), ("", true, false, true)
        ] {
            UpdateFixtureProtocol.body = Data(body.utf8); UpdateFixtureProtocol.failure = failure
            let result: (Bool, String?) = await withCheckedContinuation { continuation in
                checker.checkForUpdates(manual: true) { available, _, _, error in continuation.resume(returning: (available, error)) }
            }
            precondition(result.0 == expectedAvailable && (result.1 != nil) == expectedError, "Update result regression")
        }
        precondition(UpdateFixtureProtocol.calls == 4, "All update requests must use local fixtures")
        URLProtocol.unregisterClass(UpdateFixtureProtocol.self)
        print("Legacy login-state/quota models, cache compatibility and actual update-check service fixture tests passed. No login or installation performed.")
    }
}
