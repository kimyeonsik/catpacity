#if CATPACITY_VERIFICATION
import AppKit
import SwiftUI

/// Compiled only into the separately identified full-app verification bundle.
/// Account data below is synthetic; the normal product never links this file.
enum IntegrationVerification {
    static let bundleID = "com.yeonsik.catpacity.integration-verification"
    // Finder/native GUI launches cannot pass CLI arguments. This adjacent, explicit
    // test configuration selects only existing verification modes, never arbitrary code.
    static let arguments: [String] = {
        let process = ProcessInfo.processInfo.arguments
        guard process.count == 1 else { return process }
        let path = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("verification-options.json")
        guard let data = try? Data(contentsOf: path), let options = try? JSONDecoder().decode([String].self, from: data) else { return process }
        let allowed: Set<String> = ["--fixtures", "--self-check", "--capture-live", "--web-fallback"]
        precondition(options.allSatisfy { allowed.contains($0) }, "Unsupported verification launch option")
        return process + options
    }()
    static let fixtureReader = IntegrationFixtureReader()
    static var usesFixtures: Bool { arguments.contains("--fixtures") }
    static var usesWeb: Bool { arguments.contains("--web-fallback") }
    static var evidenceDirectory: URL {
        let arguments = Self.arguments
        if let index = arguments.firstIndex(of: "--evidence-dir"), index + 1 < arguments.count {
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        return Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("integration-evidence")
    }
    static var banner: String {
        "통합 검증 · 계정/업데이트: 테스트 자료 · CatWorks: " + (usesFixtures ? "테스트 자료" : "실제 로컬 관측")
    }

    static func prepare() {
        precondition(Bundle.main.bundleIdentifier == bundleID, "Verification requires its isolated bundle ID")
        if arguments.contains("--self-check"), usesFixtures {
            writeCheckReport(status: "starting", checks: [])
            DispatchQueue.global().asyncAfter(deadline: .now() + 45) {
                let url = evidenceDirectory.appendingPathComponent("results.json")
                if let data = try? Data(contentsOf: url),
                   var report = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    report["status"] = "timed_out"; report["exitCode"] = 124
                    try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
                }
                exit(124)
            }
        }
        // Volatile overrides never copy or rewrite the installed application's preference domain.
        UserDefaults.standard.setVolatileDomain([
            "catpacity_codex_api_key": "", "catpacity_gemini_api_key": "", "catpacity_claude_api_key": "",
            "catpacity_codex_usage_cache": Data(), "catpacity_gemini_usage_cache": Data(),
            "catpacity_claude_usage_cache": Data(), "catpacity_claude_plan_override": "auto",
            "catpacity_notify_on_high_usage": false, "catpacity_launch_at_login": false,
            "catpacity_show_codex": true, "catpacity_show_gemini": true, "catpacity_show_claude": true,
            "catpacity_menubar_mode": "cat_twoline", "catpacity_cat_status_target": "min"
        ], forName: UserDefaults.argumentDomain)
    }

    @MainActor static func makeStore() -> CatWorksStore {
        CatWorksStore(reader: usesFixtures ? fixtureReader : CatWorksHTTPReader(),
                      launcher: IntegrationLauncher())
    }

    private static func writeCheckReport(status: String, checks: [String], failed: String? = nil, exitCode: Int? = nil) {
        let report: [String: Any] = ["status": status, "checks": checks,
            "failedCheck": failed as Any? ?? NSNull(), "exitCode": exitCode as Any? ?? NSNull(),
            "scope": "Full app with synthetic account/update and companion fixtures; sleep notifications are simulated"]
        do {
            try FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: evidenceDirectory.appendingPathComponent("results.json"), options: .atomic)
        } catch { fputs("Cannot record integration test results\n", stderr); exit(2) }
    }

    @MainActor static func runChecks(_ delegate: AppDelegate) {
        if arguments.contains("--capture-live"), !usesFixtures {
            captureLive(delegate)
        }
        guard arguments.contains("--self-check"), usesFixtures else { return }
        Task { @MainActor in
            var checks: [String] = []
            func check(_ condition: Bool, _ name: String) {
                FileHandle.standardError.write(Data("\(condition ? "PASS" : "FAIL"): \(name)\n".utf8))
                if !condition { writeCheckReport(status: "failed", checks: checks, failed: name, exitCode: 1); exit(1) }
                checks.append(name)
                writeCheckReport(status: "running", checks: checks)
            }
            func settle() async { try? await Task.sleep(nanoseconds: 350_000_000) }
            @MainActor func waitUntil(_ condition: @MainActor () async -> Bool) async {
                for _ in 0..<100 {
                    if await condition() { return }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
            @MainActor func capture(_ name: String) throws {
                guard let view = delegate.popover.contentViewController?.view,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent(name + ".png"))
            }
            let output = evidenceDirectory
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                await waitUntil { delegate.popover.isShown && delegate.catWorks.summary != nil }
                check(delegate.popover.isShown, "Real NSStatusItem popover opened")
                let store = delegate.catWorks
                let previousDate = store.summary?.date
                let previousResponse = store.summary?.responseAt
                check(previousResponse.map { Date().timeIntervalSince($0) > 86_300 } == true,
                      "Previous-day companion fixture loaded before refresh")
                await fixtureReader.setMode("failure")
                await store.refresh(); await settle()
                check(store.summary?.date == previousDate && store.summary?.responseAt == previousResponse && store.errorMessage != nil,
                      "Previous-day date and values survive refresh failure")
                try capture("previous-failure")
                await fixtureReader.setMode("complete")
                await store.refresh()
                await settle()
                check(store.summary?.date != previousDate && store.errorMessage == nil, "Recovery advances reporting date")
                check(store.summary?.today.newInputTokens == 800 && store.summary?.today.cacheReadInputTokens == 400 && store.summary?.today.outputTokens == 75, "Complete companion token model (not card columns)")
                check(delegate.appState.activeRemainingPercent == 60, "Companion tokens excluded from subscription energy")
                try capture("complete")

                await fixtureReader.setMode("partial")
                await store.refresh(); await settle()
                check(store.summary?.today.status == .partial && store.summary?.today.outputTokens == nil, "Partial sum and unknown output preserved")
                try capture("partial")
                let saved = store.summary?.responseAt
                let connected = store.lastConnectedAt
                await fixtureReader.setMode("failure")
                await store.refresh(); await settle()
                check(store.summary?.responseAt == saved && store.lastConnectedAt == connected && store.errorMessage != nil, "Failure retains values, reporting date and last connection")
                try capture("failure")

                await fixtureReader.setMode("unknown")
                await store.refresh(); await settle()
                check(store.summary?.today.newInputTokens == nil && store.summary?.today.status == .unavailable, "Unavailable counts remain unknown")
                try capture("unknown")

                await fixtureReader.setMode("slow")
                let inFlight = Task { await store.refresh() }
                await settle()
                delegate.popover.performClose(nil)
                await inFlight.value
                await waitUntil { !delegate.popover.isShown }
                check(!store.isLoading, "Closing actual popover cancels refresh")
                let closedCount = await fixtureReader.count
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
                await settle()
                check(await fixtureReader.count == closedCount, "Wake does not poll a closed popover")
                await fixtureReader.setMode("complete")
                delegate.showPopover()
                await waitUntil { await fixtureReader.count > closedCount && !store.isLoading }
                check(await fixtureReader.count > closedCount && store.errorMessage == nil, "Reopening resumes polling and clears failure")
                await fixtureReader.setMode("slow")
                let sleepingRequest = Task { await store.refresh() }
                await settle()
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
                await sleepingRequest.value
                check(!store.isLoading, "Screen-sleep notification cancels request")
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
                let sleepingCount = await fixtureReader.count
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
                await settle()
                check(await fixtureReader.count == sleepingCount, "Screen wake cannot override machine sleep")
                await fixtureReader.setMode("complete")
                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
                await waitUntil { await fixtureReader.count > sleepingCount && !store.isLoading }
                check(await fixtureReader.count > sleepingCount, "Visible popover resumes after machine wake")
                check(await fixtureReader.cancellations >= 2, "In-flight tasks observed cancellation")
                delegate.appState.checkForUpdates(manual: true)
                check(delegate.appState.updateAvailable, "Update banner renders fixture")
                delegate.appState.startSelfUpdate()
                check(!delegate.appState.isSelfUpdating && delegate.appState.selfUpdateError != nil, "Verification cannot install an update")
                try capture("update")
                writeCheckReport(status: "passed", checks: checks, exitCode: 0)
                print("Integration self-check passed: \(checks.count) checks; \(output.path)")
                NSApp.terminate(nil)
            } catch {
                writeCheckReport(status: "failed", checks: checks, failed: "Evidence capture failed", exitCode: 1)
                print("Integration evidence error: \(error)")
                exit(1)
            }
        }
    }

    /// Records only the companion contract, never account data or preferences.
    /// Remains open so QA can exercise the actual card buttons after capture.
    @MainActor private static func captureLive(_ delegate: AppDelegate) {
        Task { @MainActor in
            let output = evidenceDirectory
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                for _ in 0..<100 {
                    if !delegate.catWorks.isLoading && delegate.catWorks.summary != nil { break }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                guard let summary = delegate.catWorks.summary, delegate.catWorks.errorMessage == nil,
                      delegate.popover.isShown else { throw CatWorksConnectionError.unavailable }
                // This is the store's response, not a second fetch. The compact card displays an office preview;
                // these counters are model evidence, not a claim that token columns are rendered in the card.
                let report: [String: Any] = [
                    "scope": "Live companion response held by the full isolated app; model evidence, not rendered token columns; account/update fixtures",
                    "capturedAt": ISO8601DateFormatter().string(from: Date()),
                    "responseAt": ISO8601DateFormatter().string(from: summary.responseAt),
                    "date": summary.date, "timeZone": summary.timeZone,
                    "status": summary.today.status.rawValue,
                    "newInputTokens": summary.today.newInputTokens as Any? ?? NSNull(),
                    "cacheReadInputTokens": summary.today.cacheReadInputTokens as Any? ?? NSNull(),
                    "outputTokens": summary.today.outputTokens as Any? ?? NSNull(),
                    "accountLimits": summary.accountLimits.status,
                    "providerCount": summary.providers.count
                ]
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                    .write(to: output.appendingPathComponent("live-response.json"))
                guard let view = delegate.popover.contentViewController?.view,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                    throw CatWorksConnectionError.unavailable
                }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw CatWorksConnectionError.unavailable
                }
                try png.write(to: output.appendingPathComponent("live-popover.png"))
                print("Live companion capture saved: \(output.path)")
            } catch {
                FileHandle.standardError.write(Data("Live capture failed: \(error)\n".utf8))
            }
        }
    }
}

/// Overrides only external account/update boundaries; inherited AppState layout, timers,
/// menu-bar energy, refresh dispatch and the actual PopoverView remain in use.
final class IntegrationAppState: AppState {
    override func refreshCodex() {
        var value = CodexUsage.initial
        value.isChecking = false; value.isConnected = true; value.errorMessage = nil
        value.planType = "Codex Pro · 테스트 자료"; value.usedPercent = 40
        value.resetsAt = Date().addingTimeInterval(3600); value.resetCreditsAvailableCount = 0
        overallUsage.codex = value
    }
    override func refreshGemini() {
        var value = GeminiUsage.initial
        value.isChecking = false; value.isConnected = true; value.errorMessage = nil
        value.planName = "Antigravity · 테스트 자료"; value.usedPercent = 25
        value.weeklyRemainingPercent = 65
        overallUsage.gemini = value
    }
    override func refreshClaude() {
        var value = ClaudeUsage.initial
        value.isChecking = false; value.isConnected = false
        value.errorMessage = "미로그인 상태 · 테스트 자료"
        overallUsage.claude = value
    }
    override func checkForUpdates(manual: Bool = false) {
        lastUpdateCheckTime = Date(); isCheckingUpdate = false
        updateAvailable = manual
        latestVersionTag = "v99.0.0-test"
        updateStatusMessage = "테스트 자료 · 실제 릴리스 조회 없음"
    }
    override func startSelfUpdate() {
        isSelfUpdating = false
        selfUpdateError = "검증 빌드에서는 설치본을 교체하지 않습니다."
    }
}

actor IntegrationFixtureReader: CatWorksReading {
    private var mode = IntegrationVerification.arguments.contains("--self-check") ? "previous" : "complete"
    private(set) var count = 0
    private(set) var cancellations = 0
    func setMode(_ value: String) { mode = value }
    func validateConnection() async throws { throw CatWorksConnectionError.unavailable }
    func fetchSummary() async throws -> CatWorksSummary {
        count += 1
        // Optional scenario file enables manual GUI checks without restarting the app.
        let arguments = IntegrationVerification.arguments
        let selected: String
        if let index = arguments.firstIndex(of: "--scenario"), index + 1 < arguments.count {
            selected = try String(contentsOfFile: arguments[index + 1], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        } else { selected = mode }
        if selected == "failure" { throw CatWorksConnectionError.unavailable }
        if selected == "slow" {
            do { try await Task.sleep(nanoseconds: 30_000_000_000) }
            catch { cancellations += 1; throw error }
        }
        let now = selected == "previous" ? Date().addingTimeInterval(-86_400) : Date()
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX"); day.calendar = Calendar(identifier: .gregorian)
        day.timeZone = TimeZone(identifier: "Asia/Seoul"); day.dateFormat = "yyyy-MM-dd"
        let unknown = selected == "unknown"
        let partial = selected == "partial"
        let tokens: [String: Any] = [
            "status": unknown ? "unavailable" : (partial ? "partial" : "complete"),
            "missingCount": unknown || partial ? 1 : 0,
            "inputTokens": unknown ? NSNull() : 1200, "newInputTokens": unknown ? NSNull() : 800,
            "cacheReadInputTokens": unknown ? NSNull() : 400, "cacheWriteInputTokens": NSNull(),
            "outputTokens": unknown || partial ? NSNull() : 75
        ]
        return try CatWorksSummary.decode(JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "scope": "local-observed", "responseAt": ISO8601DateFormatter().string(from: now),
            "date": day.string(from: now), "timeZone": "Asia/Seoul", "today": tokens,
            "providers": [], "accountLimits": ["status": "notIncluded"]
        ]))
    }
}

@MainActor
private struct IntegrationLauncher: CatWorksLaunching {
    func openInstalledOffice(statistics: Bool) async throws -> Bool {
        if IntegrationVerification.usesWeb { return false }
        return try await CatWorksNativeLauncher().openInstalledOffice(statistics: statistics)
    }
    func openWebOffice(statistics: Bool) -> Bool {
        CatWorksNativeLauncher().openWebOffice(statistics: statistics)
    }
}
#endif
