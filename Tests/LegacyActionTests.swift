import AppKit
import SwiftUI

private final class ReleaseProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var body = "{}"
    nonisolated(unsafe) static var fail = false
    nonisolated(unsafe) static var count = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        precondition(request.url?.absoluteString == "https://api.github.com/repos/kimyeonsik/catpacity/releases?per_page=100")
        Self.count += 1
        if Self.fail { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private struct EmptyCompanion: CatWorksReading {
    func fetchSummary() async throws -> CatWorksSummary { throw CatWorksConnectionError.unavailable }
    func validateConnection() async throws { throw CatWorksConnectionError.unavailable }
}
@MainActor private struct NoLaunch: CatWorksLaunching {
    func openInstalledOffice(statistics: Bool) async throws -> Bool { preconditionFailure("No external launch") }
    func openWebOffice(statistics: Bool) -> Bool { preconditionFailure("No external launch") }
}

@main private struct LegacyActionTests {
    @MainActor static func main() {
        let reportURL = Bundle.main.bundleIdentifier == "com.yeonsik.catpacity.action-tests"
            ? Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("action-results.json") : nil
        var checks: [[String: Any]] = []
        var actionDiagnostics: [[String: Any]] = []
        func record(_ status: String, exitCode: Int? = nil) {
            guard let reportURL else { return }
            let report: [String: Any] = ["status": status, "checks": checks, "actionDiagnostics": actionDiagnostics,
                "exitCode": exitCode as Any? ?? NSNull(),
                "scope": "Production AppState/PopoverView/UpdateCheckerService; account, installer, notification and login-item doubles",
                "interactionMode": "external-cua",
                "executable": Bundle.main.executableURL?.path ?? "",
                "recordedAt": ISO8601DateFormatter().string(from: Date())]
            do { try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL, options: .atomic) }
            catch { fputs("Cannot record action test results\n", stderr); exit(2) }
        }
        record("starting")
        // A stalled GUI bootstrap must leave a bounded, non-passing result.
        DispatchQueue.global().asyncAfter(deadline: .now() + 600) {
            if let reportURL, let data = try? Data(contentsOf: reportURL),
               var report = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                report["status"] = "timed_out"; report["exitCode"] = 124
                try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL, options: .atomic)
            }
            exit(124)
        }
        UserDefaults.standard.setVolatileDomain([
            "catpacity_codex_usage_cache": Data(), "catpacity_gemini_usage_cache": Data(),
            "catpacity_claude_usage_cache": Data(), "catpacity_menubar_mode": "cat_percent",
            "catpacity_cat_status_target": "min", "catpacity_show_codex": true,
            "catpacity_show_gemini": true, "catpacity_show_claude": true,
            "catpacity_enable_menubar_animation": false
        ], forName: UserDefaults.argumentDomain)
        URLProtocol.registerClass(ReleaseProtocol.self)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            record("running")
            let state = AppState()
            state.lastUpdateCheckTime = Date() // Avoid unrelated automatic refresh during this short test.
            // AppDelegate owns this strongly in production; AppState only borrows it.
            // Retain the test item through cleanup so its weak reference cannot expire.
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            state.statusItem = statusItem
            let companion = CatWorksStore(reader: EmptyCompanion(), launcher: NoLaunch())
            let host = NSHostingView(rootView: PopoverView(appState: state, catWorks: companion))
            let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 375, height: 900),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.title = "Catpacity isolated action tests"
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.makeKeyAndOrderFront(nil)
            app.activate(ignoringOtherApps: true)
            var passed = 0
            @MainActor func check(_ condition: Bool, _ name: String) {
                checks.append(["name": name, "passed": condition])
                record(condition ? "running" : "failed", exitCode: condition ? nil : 1)
                guard condition else { print("FAIL: \(name)"); exit(1) }
                print("PASS: \(name)"); passed += 1
            }
            @MainActor func settle(_ seconds: Double = 0.15) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            @MainActor @discardableResult func waitUntil(timeout: Double = 6, _ condition: @MainActor () -> Bool) async -> Bool {
                let deadline = Date().addingTimeInterval(timeout)
                while Date() < deadline {
                    if condition() { return true }
                    await settle(0.1)
                }
                return condition()
            }
            @MainActor func awaitButton(_ title: String, provider: String, step: Int,
                                        dispatched: @MainActor () -> Bool) async -> Bool {
                guard !dispatched() else {
                    actionDiagnostics.append(["title": title, "provider": provider, "phase": "boundary-already-called"])
                    return false
                }
                window.title = "Catpacity Tests \(step)/4 — \(provider): \(title)"
                actionDiagnostics.append(["title": title, "provider": provider, "step": step,
                    "phase": "waiting-for-external-click", "maximumWaitSeconds": 180])
                record("waiting_for_external_ui")
                // Only the production Button can reach this service double. The test
                // never invokes its action, AX press, or the external login/installer.
                let observed = await waitUntil(timeout: 180, dispatched)
                actionDiagnostics.append(["title": title, "provider": provider, "step": step,
                    "phase": observed ? "boundary-observed" : "external-click-not-observed"])
                return observed
            }
            let codexPressed = await awaitButton("터미널에서 로그인", provider: "Codex", step: 1) { CodexService.shared.login != nil }
            check(codexPressed, "Actual Codex card login button dispatches")
            check(CodexService.shared.login != nil && ClaudeService.shared.login == nil, "Codex login reaches only its external boundary")
            let claudePressed = await awaitButton("터미널에서 로그인", provider: "Claude", step: 2) { ClaudeService.shared.login != nil }
            check(claudePressed, "Actual Claude card login button dispatches")
            check(ClaudeService.shared.login != nil, "Claude login reaches its external boundary")
            let geminiPressed = await awaitButton("터미널에서 갱신", provider: "Gemini", step: 3) { GeminiService.shared.login != nil }
            check(geminiPressed, "Actual Gemini card sync button dispatches")
            check(GeminiService.shared.login != nil, "Gemini sync reaches its external boundary")
            CodexService.shared.usage.isConnected = true; CodexService.shared.usage.isChecking = false
            CodexService.shared.usage.usedPercent = 40; CodexService.shared.usage.errorMessage = nil
            ClaudeService.shared.usage.isConnected = true; ClaudeService.shared.usage.isChecking = false
            ClaudeService.shared.usage.planName = "Claude Pro"; ClaudeService.shared.usage.usedPercent = 20
            GeminiService.shared.usage.isConnected = true; GeminiService.shared.usage.isChecking = false
            GeminiService.shared.usage.usedPercent = 30
            let before = [CodexService.shared.fetches, GeminiService.shared.fetches, ClaudeService.shared.fetches]
            CodexService.shared.login?(); GeminiService.shared.login?(); ClaudeService.shared.login?()
            await waitUntil { CodexService.shared.fetches > before[0] && GeminiService.shared.fetches > before[1] && ClaudeService.shared.fetches > before[2] }
            check(state.overallUsage.codex.isConnected && state.overallUsage.gemini.isConnected && state.overallUsage.claude.isConnected,
                  "Login completion refreshes all three production AppState models")
            actionDiagnostics.append(["phase": "menu-bar-state", "expectedRemainingPercent": 60,
                "actualRemainingPercent": state.activeRemainingPercent, "expectedTitle": " 60%",
                "actualTitle": state.statusItem?.button?.title as Any? ?? NSNull(),
                "statusItemAlive": state.statusItem != nil, "statusItemMatchesOwner": state.statusItem === statusItem,
                "buttonPresent": state.statusItem?.button != nil,
                "mode": UserDefaults.standard.string(forKey: "catpacity_menubar_mode") as Any? ?? NSNull(),
                "target": state.catStatusTarget.rawValue,
                "providerUsedPercent": [state.overallUsage.codex.usedPercent, state.overallUsage.gemini.usedPercent, state.overallUsage.claude.usedPercent]])
            check(state.activeRemainingPercent == 60 && state.statusItem?.button?.title == " 60%", "Quota refresh reaches menu-bar percentage")
            CodexService.shared.usage.errorMessage = "fixture quota unavailable"
            CodexService.shared.usage.isConnected = false
            state.refreshCodex()
            check(!state.overallUsage.codex.isConnected && state.overallUsage.codex.errorMessage == "fixture quota unavailable", "Quota error reaches AppState")
            check(state.overallUsage.gemini.isConnected && state.overallUsage.claude.isConnected, "One quota error preserves other provider values")
            CodexService.shared.usage.isConnected = true; CodexService.shared.usage.errorMessage = nil
            state.refreshAll()
            check(state.overallUsage.codex.errorMessage == nil && state.activeRemainingPercent == 60, "Refresh-all recovers provider state")
            // Finish the delayed launch-time auto-check before setting release test data.
            await waitUntil { ReleaseProtocol.count > 0 && !state.isCheckingUpdate }
            check(ReleaseProtocol.count > 0 && !state.isCheckingUpdate, "Launch-time automatic update check finishes")
            ReleaseProtocol.body = "[{\"tag_name\":\"v99.0.0\",\"html_url\":\"https://github.com/kimyeonsik/catpacity/releases/tag/v99.0.0\",\"assets\":[{\"name\":\"Catpacity-macOS.zip\"}]}]"
            state.checkForUpdates(manual: true)
            check(state.isCheckingUpdate && state.updateStatusMessage == "최신 버전 확인 중...", "Manual update checking state")
            await waitUntil { !state.isCheckingUpdate }
            check(state.updateAvailable && state.latestVersionTag == "v99.0.0" && state.updateStatusMessage?.contains("새 버전") == true,
                  "Actual update service response reaches banner state")
            let updatePressed = await awaitButton("지금 업데이트", provider: "업데이트", step: 4) { !SelfUpdateService.shared.tags.isEmpty }
            check(updatePressed, "Actual update banner dispatches installation boundary")
            check(SelfUpdateService.shared.tags == ["v99.0.0"] && state.isSelfUpdating, "Selected release reaches isolated installer")
            state.startSelfUpdate()
            check(SelfUpdateService.shared.tags.count == 1, "Duplicate installation is suppressed")
            SelfUpdateService.shared.progress?("fixture download")
            check(state.selfUpdateProgressText == "fixture download", "Installer progress reaches UI state")
            SelfUpdateService.shared.failure?("fixture installation blocked")
            check(!state.isSelfUpdating && state.selfUpdateError != nil,
                  "Installer failure reaches fallback model state without installing")
            // Button visibility is verified externally with CUA; internal SwiftUI AX
            // traversal does not expose these buttons. Keep the failure UI visible
            // until the operator records a separate, reviewable observation artifact.
            window.title = "Catpacity Tests — 브라우저에서 받기 안내 화면 확인 (누르지 마세요)"
            actionDiagnostics.append(["phase": "waiting-for-fallback-observation", "title": "브라우저에서 받기",
                "instruction": "Capture the visible fallback guidance with CUA, then record its relative artifact path in external-ui-evidence.json as fallbackGuidance. Do not click the browser button.",
                "maximumWaitSeconds": 180])
            record("waiting_for_external_evidence")
            var fallbackArtifact: String?
            let evidenceRecorded = await waitUntil(timeout: 180) {
                guard let reportURL else { return false }
                let directory = reportURL.deletingLastPathComponent()
                guard let data = try? Data(contentsOf: directory.appendingPathComponent("external-ui-evidence.json")),
                      let evidence = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let relative = evidence["fallbackGuidance"] as? String,
                      !relative.isEmpty, !relative.hasPrefix("/"), !relative.split(separator: "/").contains(".."),
                      FileManager.default.fileExists(atPath: directory.appendingPathComponent(relative).path) else { return false }
                fallbackArtifact = relative
                return true
            }
            actionDiagnostics.append(["phase": evidenceRecorded ? "external-observation-artifact-recorded" : "external-observation-missing",
                "title": "브라우저에서 받기", "artifact": fallbackArtifact as Any? ?? NSNull(),
                "verification": "External CUA evidence; not an automated accessibility assertion"])
            guard evidenceRecorded else { record("external_evidence_missing", exitCode: 1); exit(1) }
            ReleaseProtocol.fail = true
            state.checkForUpdates(manual: true)
            await waitUntil { !state.isCheckingUpdate }
            check(state.updateStatusMessage?.hasPrefix("확인 실패:") == true, "Update network failure guidance")
            ReleaseProtocol.fail = false
            ReleaseProtocol.body = "[{\"tag_name\":\"v0.0.1\",\"html_url\":\"https://github.com/kimyeonsik/catpacity/releases/tag/v0.0.1\",\"assets\":[{\"name\":\"Catpacity-macOS.zip\"}]}]"
            state.checkForUpdates(manual: true)
            await waitUntil { !state.isCheckingUpdate }
            check(!state.updateAvailable && state.updateStatusMessage?.contains("최신 버전입니다") == true, "No-update guidance clears old banner")
            let requests = ReleaseProtocol.count
            state.checkAutoUpdateIfNeeded()
            await settle()
            check(ReleaseProtocol.count == requests, "Automatic update checks remain throttled")
            print("Action regression passed: \(passed) checks. Production AppState/PopoverView/UpdateCheckerService; external account, installer and notification doubles. No login, installation or personal setting changes.")
            record("passed", exitCode: 0)
            window.close()
            NSStatusBar.system.removeStatusItem(statusItem)
            app.terminate(nil)
        }
        app.run()
    }
}
