import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var appState: AppState!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce accessory policy (menu bar agent)
        NSApp.setActivationPolicy(.accessory)
        
        // Prevent duplicate instances
        let bundleID = Bundle.main.bundleIdentifier ?? "com.yeonsik.catpacity"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningApps.count > 1 {
            for app in runningApps where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        }
        
        // Initialize App State
        appState = AppState()
        
        // Setup Launch at Login (default on)
        LaunchAtLoginHelper.setupInitialState()
        
        // Setup Popover
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        self.popover = popover
        
        // Listen for dynamic popover content resize
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CatpacityPopoverResize"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.popover.isShown,
                  let host = self.popover.contentViewController else { return }
            let fitting = host.view.fittingSize
            if fitting.width > 0 && fitting.height > 0 {
                self.popover.contentSize = fitting
            }
        }
        
        // Setup Status Item in Menu Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        appState.statusItem = statusItem
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            let initialFrame = PixelArtFrames.getFrames(for: .energetic).first
            button.image = initialFrame
        }
        
        // Request notifications
        NotificationService.shared.requestAuthorization()
        
        // Initial menu bar update
        appState.updateMenuBar()
        
        // Automatically pop open on launch so the user sees it immediately!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showPopover()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }
    
    @objc func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        guard let button = statusItem?.button else { return }
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Re-host view to ensure fresh data
        let hosting = NSHostingController(
            rootView: PopoverView(appState: appState)
        )
        popover.contentViewController = hosting
        
        let fitting = hosting.view.fittingSize
        if fitting.width > 0 && fitting.height > 0 {
            popover.contentSize = fitting
        }
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "🐾 Catpacity 열기", action: #selector(togglePopover(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        if appState.updateAvailable {
            let updateTitle = "✨ 새 버전 업데이트 (\(appState.latestVersionTag))"
            menu.addItem(NSMenuItem(title: updateTitle, action: #selector(triggerSelfUpdate), keyEquivalent: "u"))
            menu.addItem(NSMenuItem.separator())
        }
        menu.addItem(NSMenuItem(title: "🔄 지금 새로고침", action: #selector(manualRefresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "❌ 종료", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc func triggerSelfUpdate() {
        showPopover()
        appState.startSelfUpdate()
    }
    
    @objc func manualRefresh() {
        appState.refreshAll()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

@main
struct CatpacityMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
