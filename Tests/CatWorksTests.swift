import AppKit
import Foundation

private func expect(_ value: Bool, _ message: String) {
    precondition(value, message)
}

private func expectRejection(_ body: () throws -> Void) {
    do { try body(); preconditionFailure("Expected a rejected contract") }
    catch {}
}

private func amount(_ value: Int = 100) -> [String: Any] {
    ["status": "partial", "missingCount": 1, "inputTokens": value,
     "newInputTokens": value - 20, "cacheReadInputTokens": 20,
     "cacheWriteInputTokens": NSNull(), "outputTokens": 5]
}

private func summaryJSON(_ value: Int = 100) -> [String: Any] {
    ["schemaVersion": 1, "scope": "local-observed", "responseAt": "2026-10-21T05:00:00.000Z",
     "date": "2026-10-21", "timeZone": "Asia/Seoul", "today": amount(value),
     "providers": [["providerId": "claude-code", "today": amount(value),
                    "lastUsageAt": "2026-10-20T20:00:00Z", "observedSince": NSNull()]],
     "accountLimits": ["status": "notIncluded"]]
}

private func data(_ value: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: value)
}

private func summary(_ value: Int = 100) throws -> CatWorksSummary {
    try CatWorksSummary.decode(data(summaryJSON(value)))
}

private func healthJSON() -> [String: Any] {
    ["application": "pixel-office-observer", "protocolVersion": 1, "pid": 123,
     "companion": ["schemaVersion": 1, "summaryPath": CatWorksContract.summaryPath,
                   "deepLinks": ["office": "catworks://office", "statistics": "catworks://statistics"]]]
}

private func testContracts() throws {
    let decoded = try summary()
    expect(decoded.today.status == .partial, "Partial coverage must survive decoding")
    expect(decoded.today.cacheWriteInputTokens == nil, "Unknown counts must stay nil")
    expect(decoded.today.newInputTokens == 80, "New input must not include cached reads")
    expect(decoded.providers.first?.lastUsageAt != decoded.responseAt, "Source time must not become response time")
    for (key, value) in [("schemaVersion", 2 as Any), ("scope", "account-wide"), ("timeZone", "UTC"),
                         ("date", "2026-02-30"), ("date", "2026-10-20"), ("responseAt", "not-a-date")] {
        var raw = summaryJSON(); raw[key] = value
        expectRejection { _ = try CatWorksSummary.decode(data(raw)) }
    }
    for (key, value) in [("inputTokens", -1 as Any), ("newInputTokens", 2.5), ("outputTokens", "10"),
                         ("missingCount", -1), ("status", "estimated"), ("newInputTokens", 500),
                         ("cacheWriteInputTokens", 500), ("outputTokens", 9_007_199_254_740_992)] {
        var raw = summaryJSON(); var tokens = amount(); tokens[key] = value; raw["today"] = tokens
        expectRejection { _ = try CatWorksSummary.decode(data(raw)) }
    }
    var unknown = summaryJSON()
    unknown["today"] = ["status": "unavailable", "missingCount": 1,
                         "inputTokens": NSNull(), "newInputTokens": NSNull(), "cacheReadInputTokens": NSNull(),
                         "cacheWriteInputTokens": NSNull(), "outputTokens": NSNull()]
    expect(try CatWorksSummary.decode(data(unknown)).today.inputTokens == nil, "Unavailable is not zero")
    try CatWorksContract.validateHealth(data(healthJSON()))
    for (key, value) in [("application", "other-app" as Any), ("protocolVersion", 2), ("pid", -1)] {
        var raw = healthJSON(); raw[key] = value
        expectRejection { try CatWorksContract.validateHealth(data(raw)) }
    }
    var raw = healthJSON()
    raw["companion"] = ["schemaVersion": 1, "summaryPath": "https://external.example/usage",
                        "deepLinks": ["office": "catworks://office", "statistics": "catworks://statistics"]]
    expectRejection { try CatWorksContract.validateHealth(data(raw)) }
    var boundary = summaryJSON()
    boundary["responseAt"] = "2026-10-20T15:00:00Z"
    expect(try CatWorksSummary.decode(data(boundary)).date == "2026-10-21", "Seoul midnight belongs to the next report day")
    boundary["responseAt"] = "2026-10-20T14:59:59Z"
    expectRejection { _ = try CatWorksSummary.decode(data(boundary)) }
    expect(CatWorksContract.officeURL(statistics: true, native: false).absoluteString == "http://127.0.0.1:4318/observe#statistics", "Web destination is fixed")
    expect(CatWorksContract.officeURL(statistics: false, native: true).absoluteString == "catworks://office", "App destination is fixed")
    expect(try CatWorksContract.connection(from: data(healthJSON())).previewSupported == false,
           "Older companion servers must keep office links without enabling preview")
    var previewHealth = healthJSON()
    var companion = previewHealth["companion"] as! [String: Any]
    let preview: [String: Any] = ["version": 1, "path": "/observe/preview", "width": 1360, "height": 760, "readOnly": true]
    companion["officePreview"] = preview; previewHealth["companion"] = companion
    expect(try CatWorksContract.connection(from: data(previewHealth)).previewSupported,
           "Only the verified read-only preview contract enables the office frame")
    for (key, value) in [("version", 2 as Any), ("path", "https://example.com"), ("path", "/observe"),
                         ("width", 800), ("height", 600), ("readOnly", false)] {
        var wrong = preview; wrong[key] = value; companion["officePreview"] = wrong; previewHealth["companion"] = companion
        expect(try !CatWorksContract.connection(from: data(previewHealth)).previewSupported,
               "Unsupported preview capability must fall back to office button")
    }
    expect(CatWorksContract.isPreviewNavigationAllowed(URL(string: "http://127.0.0.1:4318/observe/preview")!), "Fixed preview URL allowed")
    for address in ["https://127.0.0.1:4318/observe/preview", "http://localhost:4318/observe/preview",
                    "http://127.0.0.1:4330/observe/preview", "http://127.0.0.1:4318/observe",
                    "http://127.0.0.1:4318/observe/preview?redirect=https://example.com",
                    "http://127.0.0.1:4318/observe/preview#other", "http://user@127.0.0.1:4318/observe/preview",
                    "file:///observe/preview", "catworks://office"] {
        expect(!CatWorksContract.isPreviewNavigationAllowed(URL(string: address)!), "Preview navigation must reject alternate destinations")
    }
}

private final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, [String: String], Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, headers, body) = Self.handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        if status == 302, let location = headers["Location"], let target = URL(string: location) {
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func testHTTP() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FixtureURLProtocol.self]
    let reader = CatWorksHTTPReader(configuration: configuration)
    let health = try data(healthJSON())
    let usage = try data(summaryJSON())
    let headers = ["Content-Type": "application/json"]
    FixtureURLProtocol.handler = { request in
        expect(request.httpMethod == "GET", "Companion must only read")
        expect(request.url?.host == "127.0.0.1", "Companion must only use loopback")
        expect(request.value(forHTTPHeaderField: "Authorization") == nil, "Provider credentials must not be sent")
        return (200, headers, request.url!.path.hasSuffix("health") ? health : usage)
    }
    expect(try await reader.fetchSummary().today.newInputTokens == 80, "Validated summary must decode")
    for (status, responseHeaders, body) in [
        (302, ["Location": "https://external.example", "Content-Type": "application/json"], health),
        (200, ["Content-Type": "text/html"], health),
        (200, ["Content-Type": "application/json", "Content-Length": "1048577"], health),
        (200, headers, Data(repeating: 32, count: 1_048_577)),
        (200, headers, try data(["application": "other-app"]))
    ] {
        FixtureURLProtocol.handler = { request in
            expect(request.url?.host == "127.0.0.1", "HTTP redirects must never leave loopback")
            return (status, responseHeaders, body)
        }
        do { _ = try await reader.fetchSummary(); preconditionFailure("Unverified or oversized response accepted") }
        catch {}
    }
}

private actor ControlledReader: CatWorksReading {
    private(set) var count = 0
    private(set) var validations = 0
    var healthFailure = false
    private var suspendedHealth = false
    private var pendingHealth: CheckedContinuation<Void, Never>?
    func suspendHealth() { suspendedHealth = true }
    func releaseHealth() { suspendedHealth = false; pendingHealth?.resume(); pendingHealth = nil }
    private var pending: [Int: CheckedContinuation<CatWorksSummary, Error>] = [:]
    private var connection: CatWorksConnection?
    func setConnection(_ value: CatWorksConnection?) { connection = value }
    func fetchSnapshot() async throws -> CatWorksSnapshot {
        let captured = connection
        return CatWorksSnapshot(summary: try await fetchSummary(), connection: captured)
    }
    func fetchSummary() async throws -> CatWorksSummary {
        count += 1
        let id = count
        // Deliberately ignore cancellation to reproduce a late response from an old generation.
        return try await withCheckedThrowingContinuation { pending[id] = $0 }
    }
    func validateConnection() async throws {
        validations += 1
        if suspendedHealth { await withCheckedContinuation { pendingHealth = $0 } }
        if healthFailure { throw CatWorksConnectionError.incompatible }
    }
    func setHealthFailure(_ value: Bool) { healthFailure = value }
    func finish(_ id: Int, _ value: CatWorksSummary) { pending.removeValue(forKey: id)?.resume(returning: value) }
    func fail(_ id: Int) { pending.removeValue(forKey: id)?.resume(throwing: CatWorksConnectionError.unavailable) }
}

@MainActor
private final class FakeLauncher: CatWorksLaunching {
    var installed = false
    var nativeFailure = false
    var webSuccess = true
    var nativeCalls = 0
    var webCalls = 0
    var lastStatistics = false
    var isApplicationInstalled: Bool { installed }
    func openInstalledOffice(statistics: Bool) async throws -> Bool {
        nativeCalls += 1; lastStatistics = statistics
        if nativeFailure { throw CatWorksConnectionError.unavailable }
        return installed
    }
    func openWebOffice(statistics: Bool) -> Bool {
        webCalls += 1; lastStatistics = statistics; return webSuccess
    }
}

private func waitFor(_ predicate: () async -> Bool) async {
    for _ in 0..<1000 {
        if await predicate() { return }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    preconditionFailure("Timed out waiting for a fixture task")
}

@MainActor
private func testStore() async throws {
    let reader = ControlledReader()
    let launcher = FakeLauncher()
    let store = CatWorksStore(reader: reader, launcher: launcher)
    let first = Task { await store.refresh() }
    await waitFor { await reader.count == 1 }
    await store.refresh()
    expect(await reader.count == 1, "Only one refresh may be in flight")
    store.stopPolling()
    await reader.finish(1, try summary(100))
    await first.value
    expect(store.summary == nil && store.lastConnectedAt == nil && !store.isLoading, "Cancelled generations must not publish")

    let second = Task { await store.refresh() }
    await waitFor { await reader.count == 2 }
    await reader.finish(2, try summary(200))
    await second.value
    let lastConnected = store.lastConnectedAt
    expect(store.summary?.today.inputTokens == 200 && lastConnected != nil, "Successful refresh should publish")
    let failed = Task { await store.refresh() }
    await waitFor { await reader.count == 3 }
    await reader.fail(3)
    await failed.value
    expect(store.summary?.today.inputTokens == 200 && store.lastConnectedAt == lastConnected, "Failures must preserve the old value and time")
    expect(store.errorMessage != nil && store.summary?.date == "2026-10-21", "Stale date and failure must remain visible")

    store.startPolling(); store.startPolling()
    await waitFor { await reader.count == 4 }
    store.stopPolling()
    store.startPolling()
    await waitFor { await reader.count == 5 }
    await reader.finish(5, try summary(500))
    await waitFor { @MainActor in store.summary?.today.inputTokens == 500 }
    await reader.finish(4, try summary(400))
    await Task.yield()
    expect(store.summary?.today.inputTokens == 500, "Late previous polling response must not overwrite the new generation")
    store.stopPolling()

    launcher.installed = true
    await store.openOffice(statistics: true)
    expect(await reader.validations == 0, "Installed app opening must not depend on a live server")
    expect(launcher.nativeCalls == 1 && launcher.webCalls == 0 && launcher.lastStatistics, "Native fixed view must be selected")
    launcher.installed = false
    await reader.setHealthFailure(true)
    await store.openOffice()
    expect(launcher.webCalls == 0 && store.openError != nil, "An unverified server must not open in the browser")
    await reader.setHealthFailure(false)
    await store.openOffice(statistics: true)
    expect(launcher.webCalls == 1 && store.openError == nil && launcher.lastStatistics, "Verified fallback must open the fixed requested view")
}

@MainActor
private func testLifecycleAndOldResponses() async throws {
    let reader = ControlledReader()
    let store = CatWorksStore(reader: reader, launcher: FakeLauncher())
    let lifecycle = CatWorksPollingLifecycle(store: store)
    lifecycle.setSleeping(false)
    await Task.yield()
    expect(await reader.count == 0, "Waking a hidden popover must not start requests")
    lifecycle.setVisible(true)
    await waitFor { await reader.count == 1 }
    lifecycle.setScreenSleeping(true)
    expect(!store.isLoading, "Screen sleep stops in-flight refresh")
    lifecycle.setSleeping(true)
    lifecycle.setScreenSleeping(false)
    await Task.yield()
    expect(await reader.count == 1, "Screen wake cannot override system sleep")
    lifecycle.setSleeping(false)
    await waitFor { await reader.count == 2 }
    await reader.finish(2, try summary(200))
    await waitFor { @MainActor in store.summary != nil }
    await reader.finish(1, try summary(100))
    await Task.yield()
    expect(store.summary?.today.inputTokens == 200, "Pre-sleep response must not overwrite resumed request")
    lifecycle.setVisible(false)
    let checked = store.lastConnectedAt
    var older = summaryJSON(50)
    older["responseAt"] = "2026-10-21T04:59:59Z"
    let stale = Task { await store.refresh() }
    await waitFor { await reader.count == 3 }
    await reader.finish(3, try CatWorksSummary.decode(data(older)))
    await stale.value
    expect(store.summary?.today.inputTokens == 200 && store.lastConnectedAt == checked && store.errorMessage != nil,
           "An older server response must preserve the last snapshot and timestamp")
}

@MainActor
private func testOpenCancellationAndFallback() async throws {
    let reader = ControlledReader()
    let launcher = FakeLauncher()
    let store = CatWorksStore(reader: reader, launcher: launcher)
    launcher.nativeFailure = true
    await store.openOffice(statistics: true)
    expect(launcher.webCalls == 1 && launcher.lastStatistics && store.openError == nil,
           "Native launch failure uses a health-verified fallback")
    await reader.setHealthFailure(true)
    await store.openOffice()
    expect(launcher.webCalls == 1 && store.openError != nil, "Failed native launch cannot bypass health verification")
    await reader.setHealthFailure(false)
    launcher.nativeFailure = false
    launcher.webSuccess = false
    await store.openOffice()
    expect(store.openError != nil, "Web launch rejection must be visible")
    launcher.webSuccess = true
    let calls = launcher.webCalls
    await reader.suspendHealth()
    let opening = Task { await store.openOffice() }
    await waitFor { await reader.validations == 4 }
    await store.openOffice(statistics: true)
    expect(await reader.validations == 4, "Only one opening may be pending")
    store.stopPolling()
    await reader.releaseHealth()
    await opening.value
    expect(launcher.webCalls == calls && store.openError == nil,
           "Closing during health validation must cancel the eventual browser launch")
    await store.openOffice(statistics: true)
    expect(launcher.webCalls == calls + 1, "A new opening works after cancellation")
}

@MainActor
private func testPreviewLifecycle() async throws {
    let reader = ControlledReader()
    await reader.setConnection(CatWorksConnection(serverPID: 12, previewSupported: true))
    let launcher = FakeLauncher(); launcher.installed = true
    let store = CatWorksStore(reader: reader, launcher: launcher)
    let lifecycle = CatWorksPollingLifecycle(store: store)
    expect(!store.isVisible && store.previewURL == nil, "No preview may load at app startup")
    lifecycle.setVisible(true)
    await waitFor { await reader.count == 1 }
    expect(store.isInstalled && store.previewURL == nil, "Installation is observed without opening the app; preview waits for health")
    await reader.finish(1, try summary(200))
    await waitFor { @MainActor in store.previewURL != nil }
    let session = store.previewSessionID
    var disposals = 0
    store.registerPreviewDisposal(session: session) { disposals += 1 }
    store.previewFinished(session: session, failed: false)
    expect(!store.previewIsLoading, "Visible preview reports readiness")
    lifecycle.setVisible(false)
    expect(disposals == 1, "Hiding must synchronously dispose the web document even if SwiftUI does not render while hidden")
    expect(store.previewURL == nil && !store.isVisible, "Closing unmounts the preview independently of cached summary")
    store.previewFinished(session: session, failed: true)
    expect(store.previewError == nil, "Disposed preview callbacks cannot publish errors")
    store.registerPreviewDisposal(session: session) { disposals += 1 }
    expect(disposals == 2, "A late webview mounting after close must be disposed immediately")
    lifecycle.setVisible(true)
    await waitFor { await reader.count == 2 }
    expect(store.previewURL == nil && store.previewSessionID != session, "Reopening must revalidate and create a new web document")
    await reader.finish(2, try summary(300))
    await waitFor { @MainActor in store.previewURL != nil }
    store.previewFinished(session: store.previewSessionID, failed: true)
    expect(store.previewError != nil, "Preview failure is visible without losing office navigation")
    store.retryPreview()
    expect(store.previewError == nil && store.previewIsLoading, "Explicit retry resets only preview state")
    lifecycle.setSleeping(true)
    expect(store.previewURL == nil, "Sleep unmounts a visible office preview")
    lifecycle.setVisible(false)
    lifecycle.setSleeping(false)
    await Task.yield()
    expect(await reader.count == 2, "Wake must not load hidden preview or poll")
}

@main
private struct CatWorksTests {
    @MainActor static func main() async throws {
        try testContracts()
        try await testHTTP()
        try await testStore()
        try await testLifecycleAndOldResponses()
        try await testOpenCancellationAndFallback()
        try await testPreviewLifecycle()
        print("CatWorks contract, preview capability/navigation, visibility disposal, HTTP boundary, polling/cancellation and open-routing tests passed.")
    }
}
