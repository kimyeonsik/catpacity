import SwiftUI
import AppKit

public class AppState: ObservableObject {
    @Published public var overallUsage: OverallUsage = OverallUsage(
        codex: CodexUsage.initial,
        gemini: GeminiUsage.initial
    )
    @Published public var lastSyncTime: Date = Date()
    @Published public var currentAnimFrame: Int = 0
    
    public weak var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var animationTimer: Timer?
    
    public init() {
        refreshAll()
        startPeriodicRefresh()
        startMenuBarAnimation()
    }
    
    public func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        let interval = UserDefaults.standard.integer(forKey: "catpacity_refresh_interval")
        let seconds = interval > 0 ? TimeInterval(interval) : 300.0
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
    }
    
    public func startMenuBarAnimation() {
        animationTimer?.invalidate()
        
        // 350ms per frame gives an authentic, charming retro pixel-art cadence
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tickAnimation()
        }
    }
    
    private func tickAnimation() {
        let stage = overallUsage.catStage
        let frames = PixelArtFrames.getFrames(for: stage)
        guard !frames.isEmpty else { return }
        
        currentAnimFrame = (currentAnimFrame + 1) % frames.count
        
        if let button = statusItem?.button {
            button.image = frames[currentAnimFrame]
        }
    }
    
    public func refreshAll() {
        refreshCodex()
        refreshGemini()
    }
    
    public func refreshCodex() {
        CodexService.shared.fetchUsage { [weak self] usage in
            guard let self = self else { return }
            self.overallUsage.codex = usage
            self.lastSyncTime = Date()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.overallUsage.maxUsedPercent)
        }
    }
    
    public func refreshGemini() {
        GeminiService.shared.fetchUsage { [weak self] usage in
            guard let self = self else { return }
            self.overallUsage.gemini = usage
            self.lastSyncTime = Date()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.overallUsage.maxUsedPercent)
        }
    }
    
    public func updateMenuBar() {
        tickAnimation()
        updateMenuBarText()
    }
    
    public func updateMenuBarText() {
        guard let button = statusItem?.button else { return }
        
        let mode = UserDefaults.standard.string(forKey: "catpacity_menubar_mode") ?? "cat_only"
        switch mode {
        case "cat_percent":
            button.title = " \(Int(overallUsage.maxUsedPercent))%"
        case "cat_countdown":
            let resetsAt = overallUsage.codex.resetsAt ?? overallUsage.gemini.resetsAt
            button.title = " " + TimeFormatter.formatCountdown(until: resetsAt)
        default:
            button.title = ""
        }
    }
}
