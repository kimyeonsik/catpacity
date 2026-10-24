import AppKit
import SwiftUI

// Isolated UI verification: no AppState, quota providers, login items, updates or permissions.
@MainActor
private final class PreviewDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = CatWorksStore()
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let content = CatWorksCardView(store: store).padding(18).frame(width: 390)
        let host = NSHostingController(rootView: content)
        window = NSWindow(contentViewController: host)
        window.title = "CatWorks 연결 미리보기"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 390, height: 350))
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        store.startPolling()
    }

    func windowWillClose(_ notification: Notification) {
        store.stopPolling()
        NSApp.terminate(nil)
    }
}

@main
private struct CatWorksPreview {
    static func main() {
        let app = NSApplication.shared
        let delegate = PreviewDelegate()
        app.delegate = delegate
        app.run()
    }
}
