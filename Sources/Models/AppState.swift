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
    
    private var cachedTwoLine1: NSAttributedString?
    private var cachedTwoLine2: NSAttributedString?
    private var cachedTextWidth: CGFloat = 0.0
    
    public init() {
        if UserDefaults.standard.string(forKey: "catpacity_menubar_mode") == nil || UserDefaults.standard.string(forKey: "catpacity_menubar_mode") == "cat_only" {
            UserDefaults.standard.set("cat_twoline", forKey: "catpacity_menubar_mode")
        }
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
    
    public func updateTwoLineCache() {
        let boldFont = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .bold)
        let normalFont = NSFont.systemFont(ofSize: 8.0, weight: .regular)
        
        // Line 1: Codex
        let line1 = NSMutableAttributedString()
        if overallUsage.codex.isConnected {
            line1.append(NSAttributedString(string: "Codex: \(Int(overallUsage.codex.remainingPercent))%", attributes: [.font: boldFont, .foregroundColor: NSColor.labelColor]))
            let r = TimeFormatter.formatShortReset(until: overallUsage.codex.resetsAt)
            if !r.isEmpty {
                line1.append(NSAttributedString(string: " (\(r))", attributes: [.font: normalFont, .foregroundColor: NSColor.secondaryLabelColor]))
            }
        } else {
            line1.append(NSAttributedString(string: "Codex: 미연동", attributes: [.font: normalFont, .foregroundColor: NSColor.secondaryLabelColor]))
        }
        
        // Line 2: Gemini
        let line2 = NSMutableAttributedString()
        if overallUsage.gemini.isConnected {
            line2.append(NSAttributedString(string: "Gemini: \(Int(overallUsage.gemini.remainingPercent))%", attributes: [.font: boldFont, .foregroundColor: NSColor.labelColor]))
            let r = TimeFormatter.formatShortReset(until: overallUsage.gemini.resetsAt)
            if !r.isEmpty {
                line2.append(NSAttributedString(string: " (\(r))", attributes: [.font: normalFont, .foregroundColor: NSColor.secondaryLabelColor]))
            }
        } else {
            line2.append(NSAttributedString(string: "Gemini: 미연동", attributes: [.font: normalFont, .foregroundColor: NSColor.secondaryLabelColor]))
        }
        
        cachedTwoLine1 = line1
        cachedTwoLine2 = line2
        cachedTextWidth = ceil(max(line1.size().width, line2.size().width))
    }
    
    private func createTwoLineImage(catFrame: NSImage) -> NSImage {
        if cachedTwoLine1 == nil || cachedTwoLine2 == nil {
            updateTwoLineCache()
        }
        guard let line1 = cachedTwoLine1, let line2 = cachedTwoLine2 else {
            return catFrame
        }
        
        let catSize = NSSize(width: 22, height: 16)
        let totalWidth = catSize.width + 6 + cachedTextWidth
        let totalHeight: CGFloat = 22
        let size2 = line2.size()
        
        let composite = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
            let catRect = NSRect(x: 0, y: (totalHeight - catSize.height) / 2, width: catSize.width, height: catSize.height)
            catFrame.draw(in: catRect)
            
            let textX = catSize.width + 5
            let yTop = (totalHeight / 2) + 0.5
            let yBottom = (totalHeight / 2) - size2.height - 0.5
            
            line1.draw(at: NSPoint(x: textX, y: yTop))
            line2.draw(at: NSPoint(x: textX, y: yBottom))
            return true
        }
        composite.isTemplate = false
        return composite
    }
    
    private func tickAnimation() {
        let stage = overallUsage.catStage
        let frames = PixelArtFrames.getFrames(for: stage)
        guard !frames.isEmpty else { return }
        
        currentAnimFrame = (currentAnimFrame + 1) % frames.count
        
        guard let button = statusItem?.button else { return }
        let mode = UserDefaults.standard.string(forKey: "catpacity_menubar_mode") ?? "cat_twoline"
        let catFrame = frames[currentAnimFrame]
        
        if mode == "cat_twoline" {
            button.title = ""
            button.image = createTwoLineImage(catFrame: catFrame)
        } else {
            button.image = catFrame
            updateMenuBarText()
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
            self.updateTwoLineCache()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.overallUsage.maxUsedPercent)
        }
    }
    
    public func refreshGemini() {
        GeminiService.shared.fetchUsage { [weak self] usage in
            guard let self = self else { return }
            self.overallUsage.gemini = usage
            self.lastSyncTime = Date()
            self.updateTwoLineCache()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.overallUsage.maxUsedPercent)
        }
    }
    
    public func updateMenuBar() {
        updateTwoLineCache()
        tickAnimation()
        updateMenuBarText()
    }
    
    public func updateMenuBarText() {
        guard let button = statusItem?.button else { return }
        
        let mode = UserDefaults.standard.string(forKey: "catpacity_menubar_mode") ?? "cat_twoline"
        switch mode {
        case "cat_twoline":
            button.title = ""
        case "cat_percent":
            button.title = " \(Int(overallUsage.minRemainingPercent))%"
        case "cat_countdown":
            let resetsAt = overallUsage.codex.resetsAt ?? overallUsage.gemini.resetsAt
            button.title = " " + TimeFormatter.formatCountdown(until: resetsAt)
        default:
            button.title = ""
        }
    }
}
