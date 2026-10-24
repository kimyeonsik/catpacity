import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var appState: AppState!
    #if CATPACITY_VERIFICATION
    let catWorks = IntegrationVerification.makeStore()
    #else
    let catWorks = CatWorksStore()
    #endif
    lazy var catWorksLifecycle = CatWorksPollingLifecycle(store: catWorks)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce accessory policy (menu bar agent)
        NSApp.setActivationPolicy(.accessory)
        
        // Setup standard system Edit menu so Cmd+V, Cmd+C, Cmd+A work in text fields
        setupStandardEditMenu()
        
        // Prevent duplicate instances
        let bundleID = Bundle.main.bundleIdentifier ?? "com.yeonsik.catpacity"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningApps.count > 1 {
            for app in runningApps where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                app.terminate()
            }
        }
        
        // Initialize App State
        #if CATPACITY_VERIFICATION
        appState = IntegrationAppState()
        #else
        appState = AppState()
        #endif
        
        // Setup Launch at Login (default on)
        #if !CATPACITY_VERIFICATION
        LaunchAtLoginHelper.setupInitialState()
        #endif
        
        // Setup Popover
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        self.popover = popover

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(workspaceWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(workspaceDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenWillSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screenDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)

        // Listen for dynamic popover content resize
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CatpacityPopoverResize"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.popover.isShown,
                      let host = self.popover.contentViewController else { return }
                let fitting = host.view.fittingSize
                if fitting.width > 0 && fitting.height > 0 {
                    self.popover.contentSize = fitting
                }
            }
        }
        
        // Setup Status Item in Menu Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        appState.statusItem = statusItem
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            let initialFrame = PixelArtFrames.getFrames(for: .energetic, breed: appState.selectedBreed).first
            button.image = initialFrame
        }
        
        // Request notifications
        #if !CATPACITY_VERIFICATION
        NotificationService.shared.requestAuthorization()
        #endif
        
        // Initial menu bar update
        appState.updateMenuBar()
        
        // Automatically pop open on launch so the user sees it immediately!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showPopover()
            #if CATPACITY_VERIFICATION
            if let self { IntegrationVerification.runChecks(self) }
            #endif
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
            rootView: PopoverView(appState: appState, catWorks: catWorks)
        )
        popover.contentViewController = hosting
        
        let fitting = hosting.view.fittingSize
        if fitting.width > 0 && fitting.height > 0 {
            popover.contentSize = fitting
        }
        
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        
        // Auto-check for updates if needed
        appState.checkAutoUpdateIfNeeded()
    }

    func popoverDidShow(_ notification: Notification) { catWorksLifecycle.setVisible(true) }
    func popoverWillClose(_ notification: Notification) { catWorksLifecycle.setVisible(false) }
    func popoverDidClose(_ notification: Notification) { catWorksLifecycle.setVisible(false) }
    @objc private func workspaceWillSleep() { catWorksLifecycle.setSleeping(true) }
    @objc private func workspaceDidWake() { catWorksLifecycle.setSleeping(false) }
    @objc private func screenWillSleep() { catWorksLifecycle.setScreenSleeping(true) }
    @objc private func screenDidWake() { catWorksLifecycle.setScreenSleeping(false) }
    func applicationWillTerminate(_ notification: Notification) { catWorks.stopPolling() }
    
    private func setupStandardEditMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Catpacity", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
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
        #if CATPACITY_VERIFICATION
        IntegrationVerification.prepare()
        #endif
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
