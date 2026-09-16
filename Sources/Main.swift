import AppKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var appState: AppState!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize App State
        appState = AppState()
        
        // Setup Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 330, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(appState: appState)
        )
        self.popover = popover
        
        // Setup Status Item in Menu Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        appState.statusItem = statusItem
        
        if let button = statusItem.button {
            button.image = MenuBarIconGenerator.generateIcon(for: .energetic)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Request notifications
        NotificationService.shared.requestAuthorization()
        
        // Initial update
        appState.updateMenuBar()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Re-render popover view to ensure fresh state
            popover.contentViewController = NSHostingController(
                rootView: PopoverView(appState: appState)
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
