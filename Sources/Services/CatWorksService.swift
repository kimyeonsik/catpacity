import AppKit
import Combine
import Foundation

protocol CatWorksReading: Sendable {
    func fetchSummary() async throws -> CatWorksSummary
    func validateConnection() async throws
    func fetchSnapshot() async throws -> CatWorksSnapshot
}

extension CatWorksReading {
    func fetchSnapshot() async throws -> CatWorksSnapshot {
        CatWorksSnapshot(summary: try await fetchSummary(), connection: nil)
    }
}

private final class CatWorksRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct CatWorksHTTPReader: CatWorksReading {
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        session = URLSession(configuration: configuration, delegate: CatWorksRedirectPolicy(), delegateQueue: nil)
    }

    func validateConnection() async throws {
        try CatWorksContract.validateHealth(await data(path: "/api/office/health"))
    }

    func fetchSummary() async throws -> CatWorksSummary {
        try await fetchSnapshot().summary
    }

    func fetchSnapshot() async throws -> CatWorksSnapshot {
        let connection = try CatWorksContract.connection(from: await data(path: "/api/office/health"))
        try Task.checkCancellation()
        let summary = try CatWorksSummary.decode(await data(path: CatWorksContract.summaryPath))
        return CatWorksSnapshot(summary: summary, connection: connection)
    }

    private func data(path: String) async throws -> Data {
        let url = CatWorksContract.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 2)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url == url, http.mimeType?.lowercased() == "application/json" else {
            throw CatWorksConnectionError.invalidResponse
        }
        guard response.expectedContentLength <= CatWorksContract.maximumBytes else {
            throw CatWorksConnectionError.tooLarge
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < CatWorksContract.maximumBytes else { throw CatWorksConnectionError.tooLarge }
            if data.count % 1024 == 0 { try Task.checkCancellation() }
            data.append(byte)
        }
        try Task.checkCancellation()
        return data
    }
}

@MainActor
protocol CatWorksLaunching {
    var isApplicationInstalled: Bool { get }
    func openInstalledOffice(statistics: Bool) async throws -> Bool
    func openWebOffice(statistics: Bool) -> Bool
}

extension CatWorksLaunching {
    var isApplicationInstalled: Bool { false }
}

@MainActor
struct CatWorksNativeLauncher: CatWorksLaunching {
    private func installedApplication() -> URL? {
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: CatWorksContract.bundleID),
              let bundle = Bundle(url: application), bundle.bundleIdentifier == CatWorksContract.bundleID,
              let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
              types.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains("catworks") == true }) else {
            return nil
        }
        return application
    }

    var isApplicationInstalled: Bool { installedApplication() != nil }

    func openInstalledOffice(statistics: Bool) async throws -> Bool {
        // Resolve and validate again at the moment of the user's click, never trust a cached path.
        guard let application = installedApplication() else { return false }
        let workspace = NSWorkspace.shared
        let url = CatWorksContract.officeURL(statistics: statistics, native: true)
        return try await withCheckedThrowingContinuation { continuation in
            workspace.open([url], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: true) }
            }
        }
    }

    func openWebOffice(statistics: Bool) -> Bool {
        NSWorkspace.shared.open(CatWorksContract.officeURL(statistics: statistics, native: false))
    }
}

@MainActor
public final class CatWorksStore: ObservableObject {
    @Published public private(set) var summary: CatWorksSummary?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastConnectedAt: Date?
    @Published public private(set) var openError: String?
    @Published public private(set) var isInstalled = false
    @Published public private(set) var isVisible = false
    @Published public private(set) var previewSupported = false
    @Published public private(set) var previewSessionID = UUID()
    @Published public private(set) var previewError: String?
    @Published public private(set) var previewIsLoading = true
    @Published public private(set) var isOpening = false

    public var isConnected: Bool { lastConnectedAt != nil && errorMessage == nil }
    public var previewURL: URL? {
        guard isVisible && isConnected && previewSupported else { return nil }
        return CatWorksContract.baseURL.appendingPathComponent(CatWorksContract.previewPath)
    }

    private let reader: any CatWorksReading
    private let launcher: any CatWorksLaunching
    private var pollingTask: Task<Void, Never>?
    private var refreshTask: Task<CatWorksSnapshot, Error>?
    private var refreshID: UUID?
    private var generation = 0
    private var openTask: Task<Bool, Error>?
    private var openID: UUID?
    private var serverPID: Int?
    private var previewDisposal: (session: UUID, dispose: () -> Void)?

    public convenience init() {
        self.init(reader: CatWorksHTTPReader(), launcher: CatWorksNativeLauncher())
    }

    init(reader: any CatWorksReading, launcher: any CatWorksLaunching) {
        self.reader = reader
        self.launcher = launcher
    }

    deinit {
        pollingTask?.cancel()
        refreshTask?.cancel()
        openTask?.cancel()
    }

    public func startPolling() {
        guard pollingTask == nil else { return }
        isVisible = true
        previewSupported = false // Revalidate before remounting a previously hidden preview.
        retryPreview()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                await self?.refresh()
                do { try await Task.sleep(nanoseconds: 15_000_000_000) }
                catch { return }
            }
        }
    }

    public func stopPolling() {
        disposePreview()
        isVisible = false
        previewSessionID = UUID()
        generation += 1
        pollingTask?.cancel()
        pollingTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = nil
        isLoading = false
        openTask?.cancel()
        openTask = nil
        openID = nil
        isOpening = false
    }

    public func refresh() async {
        guard refreshTask == nil, !Task.isCancelled else { return }
        isInstalled = launcher.isApplicationInstalled
        let currentGeneration = generation
        let requestID = UUID()
        let source = reader
        let task = Task { try await source.fetchSnapshot() }
        refreshTask = task
        refreshID = requestID
        isLoading = true
        defer {
            if refreshID == requestID {
                refreshTask = nil
                refreshID = nil
                isLoading = false
            }
        }
        do {
            let snapshot = try await task.value
            let value = snapshot.summary
            guard currentGeneration == generation, refreshID == requestID, !Task.isCancelled else { return }
            let changedServer = serverPID != nil && snapshot.connection?.serverPID != serverPID
            if !changedServer, let previous = summary, value.responseAt < previous.responseAt {
                throw CatWorksConnectionError.invalidResponse
            }
            if changedServer || errorMessage != nil || (!previewSupported && snapshot.connection?.previewSupported == true) {
                retryPreview()
            }
            serverPID = snapshot.connection?.serverPID
            previewSupported = snapshot.connection?.previewSupported == true
            summary = value
            lastConnectedAt = Date()
            errorMessage = nil
        } catch {
            guard currentGeneration == generation, refreshID == requestID, !Task.isCancelled else { return }
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            errorMessage = (error as? CatWorksConnectionError)?.errorDescription
                ?? CatWorksConnectionError.unavailable.errorDescription
        }
    }

    public func retryPreview() {
        disposePreview()
        previewSessionID = UUID()
        previewError = nil
        previewIsLoading = true
    }

    func registerPreviewDisposal(session: UUID, dispose: @escaping () -> Void) {
        guard isVisible, session == previewSessionID else { dispose(); return }
        disposePreview()
        previewDisposal = (session, dispose)
    }

    func unregisterPreviewDisposal(session: UUID) {
        if previewDisposal?.session == session { previewDisposal = nil }
    }

    private func disposePreview() {
        let pending = previewDisposal
        previewDisposal = nil
        pending?.dispose()
    }

    func previewFinished(session: UUID, failed: Bool) {
        guard isVisible, session == previewSessionID else { return }
        previewIsLoading = false
        previewError = failed ? "미리보기를 불러오지 못했어요. 사무실은 직접 열 수 있어요." : nil
    }

    public func openOffice(statistics: Bool = false) async {
        guard openTask == nil, !Task.isCancelled else { return }
        let requestID = UUID()
        let currentGeneration = generation
        let source = reader
        let destination = launcher
        openError = nil
        isOpening = true
        isInstalled = destination.isApplicationInstalled
        let task = Task { @MainActor in
            do {
                if try await destination.openInstalledOffice(statistics: statistics) { return true }
            } catch {
                // A registered app can fail to launch. Verify the local server before falling back.
                try Task.checkCancellation()
            }
            try Task.checkCancellation()
            try await source.validateConnection()
            try Task.checkCancellation()
            return destination.openWebOffice(statistics: statistics)
        }
        openTask = task
        openID = requestID
        defer {
            if openID == requestID { openTask = nil; openID = nil; isOpening = false }
        }
        do {
            if try await !task.value { throw CatWorksConnectionError.unavailable }
        } catch {
            guard currentGeneration == generation, openID == requestID, !Task.isCancelled else { return }
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            openError = (error as? CatWorksConnectionError)?.errorDescription
                ?? "사무실을 열지 못했습니다. 앱 설치 또는 로컬 서버 실행 상태를 확인해주세요."
        }
    }
}

/// Visibility and sleep are independent: closing or waking a hidden popover must not resume work.
@MainActor
final class CatWorksPollingLifecycle {
    private let store: CatWorksStore
    private var visible = false
    private var sleeping = false
    private var screenSleeping = false

    init(store: CatWorksStore) { self.store = store }
    func setVisible(_ value: Bool) { visible = value; reconcile() }
    func setSleeping(_ value: Bool) { sleeping = value; reconcile() }
    func setScreenSleeping(_ value: Bool) { screenSleeping = value; reconcile() }
    private func reconcile() {
        if visible && !sleeping && !screenSleeping { store.startPolling() }
        else { store.stopPolling() }
    }
}
