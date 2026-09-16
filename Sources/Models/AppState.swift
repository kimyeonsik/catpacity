import SwiftUI
import AppKit

public class AppState: ObservableObject {
    @Published public var overallUsage: OverallUsage = OverallUsage(
        codex: CodexUsage.initial,
        gemini: GeminiUsage.initial,
        claude: ClaudeUsage.initial
    )
    @Published public var lastSyncTime: Date = Date()
    @Published public var currentAnimFrame: Int = 0
    
    public weak var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var animationTimer: Timer?
    
    private var cachedAttrLines: [NSAttributedString] = []
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
    
    public func updateLineCache() {
        let showCodex = UserDefaults.standard.object(forKey: "catpacity_show_codex") as? Bool ?? true
        let showGemini = UserDefaults.standard.object(forKey: "catpacity_show_gemini") as? Bool ?? true
        let showClaude = UserDefaults.standard.object(forKey: "catpacity_show_claude") as? Bool ?? true
        let showPercent = UserDefaults.standard.object(forKey: "catpacity_show_percent") as? Bool ?? true
        let showReset = UserDefaults.standard.object(forKey: "catpacity_show_reset_time") as? Bool ?? true
        
        var providers: [(name: String, isConnected: Bool, remaining: Double, resetsAt: Date?)] = []
        if showCodex {
            providers.append(("Codex", overallUsage.codex.isConnected, overallUsage.codex.remainingPercent, overallUsage.codex.resetsAt))
        }
        if showGemini {
            providers.append(("Gemini", overallUsage.gemini.isConnected, overallUsage.gemini.remainingPercent, overallUsage.gemini.resetsAt))
        }
        if showClaude {
            providers.append(("Claude", overallUsage.claude.isConnected, overallUsage.claude.remainingPercent, overallUsage.claude.resetsAt))
        }
        
        guard !providers.isEmpty else {
            cachedAttrLines = []
            cachedTextWidth = 0.0
            return
        }
        
        let boldFont: NSFont
        let normalFont: NSFont
        
        switch providers.count {
        case 1:
            boldFont = NSFont.monospacedDigitSystemFont(ofSize: 10.0, weight: .bold)
            normalFont = NSFont.systemFont(ofSize: 9.5, weight: .regular)
        case 2:
            boldFont = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .bold)
            normalFont = NSFont.systemFont(ofSize: 8.0, weight: .regular)
        default:
            boldFont = NSFont.monospacedDigitSystemFont(ofSize: 6.8, weight: .bold)
            normalFont = NSFont.systemFont(ofSize: 6.5, weight: .regular)
        }
        
        var lines: [NSAttributedString] = []
        for p in providers {
            let str = NSMutableAttributedString()
            if !p.isConnected {
                str.append(NSAttributedString(string: "\(p.name): 미연동", attributes: [.font: normalFont, .foregroundColor: NSColor.secondaryLabelColor]))
            } else {
                var prefix = "\(p.name):"
                if showPercent {
                    prefix += " \(Int(p.remaining))%"
                }
                str.append(NSAttributedString(string: prefix, attributes: [.font: boldFont, .foregroundColor: NSColor.labelColor]))
                
                if showReset {
                    let r = TimeFormatter.formatShortReset(until: p.resetsAt)
                    if !r.isEmpty {
                        let resetText = showPercent ? " (\(r))" : " \(r)"
                        str.append(NSAttributedString(string: resetText, attributes: [.font: normalFont, .foregroundColor: NSColor.secondaryLabelColor]))
                    }
                }
            }
            lines.append(str)
        }
        
        cachedAttrLines = lines
        cachedTextWidth = lines.map { ceil($0.size().width) }.max() ?? 60.0
    }
    
    private func createDynamicMenuImage(catFrame: NSImage) -> NSImage {
        if cachedAttrLines.isEmpty {
            updateLineCache()
        }
        guard !cachedAttrLines.isEmpty else {
            return catFrame
        }
        
        let catSize = NSSize(width: 22, height: 16)
        let totalWidth = catSize.width + 6 + cachedTextWidth
        let totalHeight: CGFloat = 22
        let lines = cachedAttrLines
        
        let yPositions: [CGFloat]
        switch lines.count {
        case 1:
            yPositions = [(totalHeight - lines[0].size().height) / 2]
        case 2:
            let h1 = lines[1].size().height
            yPositions = [(totalHeight / 2) + 0.5, (totalHeight / 2) - h1 - 0.5]
        default:
            yPositions = [14.5, 7.5, 0.5]
        }
        
        let composite = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
            let catRect = NSRect(x: 0, y: (totalHeight - catSize.height) / 2, width: catSize.width, height: catSize.height)
            catFrame.draw(in: catRect)
            
            let textX = catSize.width + 5
            for (i, line) in lines.enumerated() {
                if i < yPositions.count {
                    line.draw(at: NSPoint(x: textX, y: yPositions[i]))
                }
            }
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
        
        if mode == "cat_twoline" || mode == "cat_dynamic" {
            button.title = ""
            button.image = createDynamicMenuImage(catFrame: catFrame)
        } else {
            button.image = catFrame
            updateMenuBarText()
        }
    }
    
    public func refreshAll() {
        refreshCodex()
        refreshGemini()
        refreshClaude()
    }
    
    public func refreshCodex() {
        CodexService.shared.fetchUsage { [weak self] usage in
            guard let self = self else { return }
            self.overallUsage.codex = usage
            self.lastSyncTime = Date()
            self.updateLineCache()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.overallUsage.maxUsedPercent)
        }
    }
    
    public func refreshGemini() {
        GeminiService.shared.fetchUsage { [weak self] usage in
            guard let self = self else { return }
            self.overallUsage.gemini = usage
            self.lastSyncTime = Date()
            self.updateLineCache()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.overallUsage.maxUsedPercent)
        }
    }
    
    public func refreshClaude() {
        ClaudeService.shared.fetchUsage { [weak self] usage in
            guard let self = self else { return }
            self.overallUsage.claude = usage
            self.lastSyncTime = Date()
            self.updateLineCache()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.overallUsage.maxUsedPercent)
        }
    }
    
    public func updateMenuBar() {
        updateLineCache()
        tickAnimation()
        updateMenuBarText()
    }
    
    public func updateMenuBarText() {
        guard let button = statusItem?.button else { return }
        
        let mode = UserDefaults.standard.string(forKey: "catpacity_menubar_mode") ?? "cat_twoline"
        switch mode {
        case "cat_twoline", "cat_dynamic":
            button.title = ""
        case "cat_percent":
            button.title = " \(Int(overallUsage.minRemainingPercent))%"
        case "cat_countdown":
            let resetsAt = overallUsage.codex.resetsAt ?? overallUsage.gemini.resetsAt ?? overallUsage.claude.resetsAt
            button.title = " " + TimeFormatter.formatCountdown(until: resetsAt)
        default:
            button.title = ""
        }
    }
}
