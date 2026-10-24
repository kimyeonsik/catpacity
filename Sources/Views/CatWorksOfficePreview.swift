import AppKit
import SwiftUI
import WebKit

/// Disposable, read-only view of the verified local office; no native JavaScript bridge.
@MainActor
struct CatWorksOfficePreview: NSViewRepresentable {
    let url: URL
    let store: CatWorksStore
    let session: UUID
    let onFinished: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(store: store, session: session, onFinished: onFinished) }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = ReadOnlyOfficeWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.setAccessibilityElement(false)
        context.coordinator.begin(webView, url: url)
        return webView
    }
    func updateNSView(_ webView: WKWebView, context: Context) {}
    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) { coordinator.dispose(webView) }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let onFinished: (Bool) -> Void
        private weak var store: CatWorksStore?
        private let session: UUID
        private var timeout: Task<Void, Never>?
        private var disposed = false
        private var finished = false
        init(store: CatWorksStore, session: UUID, onFinished: @escaping (Bool) -> Void) {
            self.store = store; self.session = session; self.onFinished = onFinished
        }
        func begin(_ webView: WKWebView, url: URL) {
            guard CatWorksContract.isPreviewNavigationAllowed(url) else { complete(failed: true); return }
            store?.registerPreviewDisposal(session: session) { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.dispose(webView)
            }
            guard !disposed else { return }
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5))
            timeout = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 6_000_000_000) } catch { return }
                self?.complete(failed: true)
            }
        }
        func dispose(_ webView: WKWebView) {
            guard !disposed else { return }
            disposed = true
            store?.unregisterPreviewDisposal(session: session)
            timeout?.cancel(); timeout = nil
            webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('catworks-preview-visibility', {detail:{visible:false}}));", completionHandler: nil)
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            // Document replacement ends EventSource connections, fetches and animation frames.
            webView.loadHTMLString("<!doctype html><html></html>", baseURL: nil)
        }
        private func complete(failed: Bool) {
            guard !disposed, !finished else { return }
            finished = true
            timeout?.cancel(); timeout = nil
            Task { @MainActor [weak self] in
                guard let self, !self.disposed else { return }
                self.onFinished(failed)
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard !disposed, action.targetFrame?.isMainFrame == true, action.request.httpMethod == "GET",
                  let destination = action.request.url, CatWorksContract.isPreviewNavigationAllowed(destination) else {
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            guard !disposed, response.isForMainFrame,
                  let http = response.response as? HTTPURLResponse, http.statusCode == 200,
                  let destination = http.url, CatWorksContract.isPreviewNavigationAllowed(destination),
                  http.mimeType?.lowercased() == "text/html" else {
                decisionHandler(.cancel); complete(failed: true); return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let destination = webView.url, CatWorksContract.isPreviewNavigationAllowed(destination) else {
                complete(failed: true); return
            }
            webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('catworks-preview-visibility', {detail:{visible:true}}));", completionHandler: nil)
            complete(failed: false)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { complete(failed: true) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { complete(failed: true) }
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard !disposed else { return }
            finished = false
            complete(failed: true)
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
    }
}

@MainActor
private final class ReadOnlyOfficeWebView: WKWebView {
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
