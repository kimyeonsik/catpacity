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
    
    // Update Checker & Self Update
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersionTag: String = ""
    @Published public var latestReleaseUrl: String = ""
    @Published public var isCheckingUpdate: Bool = false
    @Published public var updateStatusMessage: String? = nil
    @Published public var isSelfUpdating: Bool = false
    @Published public var selfUpdateProgressText: String = ""
    @Published public var selfUpdateError: String? = nil
    
    public var catStatusTarget: CatStatusTarget {
        let raw = UserDefaults.standard.string(forKey: "catpacity_cat_status_target") ?? "min"
        return CatStatusTarget(rawValue: raw) ?? .min
    }
    
    public var activeRemainingInfo: (percent: Double, targetName: String) {
        let showCodex = UserDefaults.standard.object(forKey: "catpacity_show_codex") as? Bool ?? true
        let showGemini = UserDefaults.standard.object(forKey: "catpacity_show_gemini") as? Bool ?? true
        let showClaude = UserDefaults.standard.object(forKey: "catpacity_show_claude") as? Bool ?? true
        return overallUsage.remainingPercent(
            for: catStatusTarget,
            showCodex: showCodex,
            showGemini: showGemini,
            showClaude: showClaude
        )
    }
    
    public var activeRemainingPercent: Double {
        return activeRemainingInfo.percent
    }
    
    public var activeTargetLabel: String {
        return activeRemainingInfo.targetName
    }
    
    public var activeMaxUsedPercent: Double {
        return max(0.0, 100.0 - activeRemainingPercent)
    }
    
    public var activeCatStage: CatStage {
        return CatStage.from(remainingPercent: activeRemainingPercent)
    }

    
    public weak var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var animationTimer: Timer?
    private var updateCheckTimer: Timer?
    
    private var cachedAttrLines: [NSAttributedString] = []
    private var cachedTextWidth: CGFloat = 0.0
    private var cachedCompositeFrames: [NSImage] = []
    private var isScreenSleeping = false
    
    public var isAnimationEnabled: Bool {
        return UserDefaults.standard.object(forKey: "catpacity_enable_menubar_animation") as? Bool ?? true
    }
    
    public var pauseOnBatteryEnabled: Bool {
        return UserDefaults.standard.object(forKey: "catpacity_pause_on_battery") as? Bool ?? true
    }
    
    public var configuredAnimationInterval: TimeInterval {
        let speed = UserDefaults.standard.double(forKey: "catpacity_animation_speed")
        return speed > 0 ? speed : 1.2 // 1.2s default: smooth, relaxing & ultra energy efficient
    }
    
    public var shouldRunAnimation: Bool {
        guard !isScreenSleeping else { return false }
        guard isAnimationEnabled else { return false }
        if pauseOnBatteryEnabled && PowerHelper.isOnBatteryPower {
            return false
        }
        return true
    }
    
    public init() {
        if UserDefaults.standard.string(forKey: "catpacity_menubar_mode") == nil || UserDefaults.standard.string(forKey: "catpacity_menubar_mode") == "cat_only" {
            UserDefaults.standard.set("cat_twoline", forKey: "catpacity_menubar_mode")
        }
        
        setupSleepAndPowerObservers()
        
        refreshAll()
        startPeriodicRefresh()
        startMenuBarAnimation()
        
        // Check for updates shortly after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.checkForUpdates()
        }
    }
    
    private func setupSleepAndPowerObservers() {
        // Completely suspend animations and background CLI calls when screen is off
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(self, selector: #selector(handleScreenSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(handleScreenWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(handleSessionResignActive), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        wsCenter.addObserver(self, selector: #selector(handleSessionBecomeActive), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePowerStateChanged), name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
    }
    
    @objc private func handleScreenSleep() {
        isScreenSleeping = true
        stopMenuBarAnimation()
    }
    
    @objc private func handleScreenWake() {
        isScreenSleeping = false
        startMenuBarAnimation()
        if Date().timeIntervalSince(lastSyncTime) > 300 {
            refreshAll()
        }
    }
    
    @objc private func handleSessionResignActive() {
        isScreenSleeping = true
        stopMenuBarAnimation()
    }
    
    @objc private func handleSessionBecomeActive() {
        isScreenSleeping = false
        startMenuBarAnimation()
    }
    
    @objc private func handlePowerStateChanged() {
        // When user unplugs or plugs in Mac, update animation state according to battery saver settings
        startMenuBarAnimation()
    }
    
    public func startPeriodicRefresh() {
        refreshTimer?.invalidate()
        let interval = UserDefaults.standard.integer(forKey: "catpacity_refresh_interval")
        let seconds = interval > 0 ? TimeInterval(interval) : 300.0
        
        let timer = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Do not wake CPU to query external processes when screen is asleep
            guard !self.isScreenSleeping else { return }
            self.refreshAll()
        }
        timer.tolerance = seconds * 0.1
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }
    
    public func startMenuBarAnimation() {
        stopMenuBarAnimation()
        rebuildCompositeFrames()
        
        guard shouldRunAnimation else {
            showStaticMenuFrame()
            return
        }
        
        let interval = configuredAnimationInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tickAnimation()
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
        
        // Immediate first frame
        tickAnimation()
    }
    
    public func stopMenuBarAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    public func showStaticMenuFrame() {
        guard let button = statusItem?.button else { return }
        if cachedCompositeFrames.isEmpty {
            rebuildCompositeFrames()
        }
        let mode = UserDefaults.standard.string(forKey: "catpacity_menubar_mode") ?? "cat_twoline"
        if mode == "cat_twoline" || mode == "cat_dynamic" {
            button.title = ""
            if let first = cachedCompositeFrames.first {
                button.image = first
            }
        } else {
            let stageFrames = PixelArtFrames.getFrames(for: activeCatStage)
            button.image = stageFrames.first
            updateMenuBarText()
        }
    }

    
    public func updateLineCache() {
        let showCodex = UserDefaults.standard.object(forKey: "catpacity_show_codex") as? Bool ?? true
        let showGemini = UserDefaults.standard.object(forKey: "catpacity_show_gemini") as? Bool ?? true
        let showClaude = UserDefaults.standard.object(forKey: "catpacity_show_claude") as? Bool ?? true
        let showPercent = UserDefaults.standard.object(forKey: "catpacity_show_percent") as? Bool ?? true
        let showReset = UserDefaults.standard.object(forKey: "catpacity_show_reset_time") as? Bool ?? true
        
        var providers: [(name: String, isConnected: Bool, isChecking: Bool, remaining: Double, resetsAt: Date?)] = []
        if showCodex {
            providers.append(("Codex", overallUsage.codex.isConnected, overallUsage.codex.isChecking, overallUsage.codex.remainingPercent, overallUsage.codex.resetsAt))
        }
        if showGemini {
            providers.append(("Gemini", overallUsage.gemini.isConnected, overallUsage.gemini.isChecking, overallUsage.gemini.remainingPercent, overallUsage.gemini.resetsAt))
        }
        if showClaude {
            providers.append(("Claude", overallUsage.claude.isConnected, overallUsage.claude.isChecking, overallUsage.claude.remainingPercent, overallUsage.claude.resetsAt))
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
                let statusText = p.isChecking ? "\(p.name): 확인 중..." : "\(p.name): 미연동"
                str.append(NSAttributedString(string: statusText, attributes: [.font: normalFont, .foregroundColor: NSColor.secondaryLabelColor]))
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
        rebuildCompositeFrames()
    }
    
    public func rebuildCompositeFrames() {
        let stage = activeCatStage
        let frames = PixelArtFrames.getFrames(for: stage)
        guard !frames.isEmpty else {
            cachedCompositeFrames = []
            return
        }
        
        let mode = UserDefaults.standard.string(forKey: "catpacity_menubar_mode") ?? "cat_twoline"
        if mode != "cat_twoline" && mode != "cat_dynamic" {
            cachedCompositeFrames = frames
            return
        }
        
        guard !cachedAttrLines.isEmpty else {
            cachedCompositeFrames = frames
            return
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
        
        var newFrames: [NSImage] = []
        for catFrame in frames {
            let composite = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
            composite.lockFocus()
            let catRect = NSRect(x: 0, y: (totalHeight - catSize.height) / 2, width: catSize.width, height: catSize.height)
            catFrame.draw(in: catRect)
            
            let textX = catSize.width + 5
            for (i, line) in lines.enumerated() {
                if i < yPositions.count {
                    line.draw(at: NSPoint(x: textX, y: yPositions[i]))
                }
            }
            composite.unlockFocus()
            composite.isTemplate = false
            newFrames.append(composite)
        }
        cachedCompositeFrames = newFrames
    }
    
    private func tickAnimation() {
        if cachedCompositeFrames.isEmpty {
            rebuildCompositeFrames()
        }
        guard !cachedCompositeFrames.isEmpty else { return }
        
        currentAnimFrame = (currentAnimFrame + 1) % cachedCompositeFrames.count
        
        guard let button = statusItem?.button else { return }
        let mode = UserDefaults.standard.string(forKey: "catpacity_menubar_mode") ?? "cat_twoline"
        
        if mode == "cat_twoline" || mode == "cat_dynamic" {
            button.title = ""
            button.image = cachedCompositeFrames[currentAnimFrame]
        } else {
            let stageFrames = PixelArtFrames.getFrames(for: activeCatStage)
            if !stageFrames.isEmpty {
                button.image = stageFrames[currentAnimFrame % stageFrames.count]
            }
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
            NotificationService.shared.checkAndNotify(usedPercent: self.activeMaxUsedPercent)
        }
    }
    
    public func refreshGemini() {
        GeminiService.shared.fetchUsage { [weak self] usage in
            guard let self = self else { return }
            self.overallUsage.gemini = usage
            self.lastSyncTime = Date()
            self.updateLineCache()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.activeMaxUsedPercent)
        }
    }
    
    public func refreshClaude() {
        ClaudeService.shared.fetchUsage { [weak self] usage in
            guard let self = self else { return }
            self.overallUsage.claude = usage
            self.lastSyncTime = Date()
            self.updateLineCache()
            self.updateMenuBarText()
            NotificationService.shared.checkAndNotify(usedPercent: self.activeMaxUsedPercent)
        }
    }
    
    public func updateMenuBar() {
        updateLineCache()
        if shouldRunAnimation {
            if animationTimer == nil {
                startMenuBarAnimation()
            } else {
                tickAnimation()
            }
        } else {
            stopMenuBarAnimation()
            showStaticMenuFrame()
        }
        updateMenuBarText()
    }

    
    public func updateMenuBarText() {
        guard let button = statusItem?.button else { return }
        
        let mode = UserDefaults.standard.string(forKey: "catpacity_menubar_mode") ?? "cat_twoline"
        switch mode {
        case "cat_twoline", "cat_dynamic":
            button.title = ""
        case "cat_percent":
            button.title = " \(Int(activeRemainingPercent))%"
        case "cat_countdown":
            var resets: [Date] = []
            let showCodex = UserDefaults.standard.object(forKey: "catpacity_show_codex") as? Bool ?? true
            let showGemini = UserDefaults.standard.object(forKey: "catpacity_show_gemini") as? Bool ?? true
            let showClaude = UserDefaults.standard.object(forKey: "catpacity_show_claude") as? Bool ?? true
            if showCodex, let r = overallUsage.codex.resetsAt { resets.append(r) }
            if showGemini, let r = overallUsage.gemini.resetsAt { resets.append(r) }
            if showClaude, let r = overallUsage.claude.resetsAt { resets.append(r) }
            let nearestReset = resets.sorted().first
            button.title = " " + TimeFormatter.formatCountdown(until: nearestReset)
        default:
            button.title = ""
        }
    }
    
    public func checkForUpdates(manual: Bool = false) {
        if isCheckingUpdate { return }
        isCheckingUpdate = true
        if manual {
            updateStatusMessage = "최신 버전 확인 중..."
        }
        
        UpdateCheckerService.shared.checkForUpdates(manual: manual) { [weak self] available, tag, url, error in
            guard let self = self else { return }
            self.isCheckingUpdate = false
            self.updateAvailable = available
            self.latestVersionTag = tag
            self.latestReleaseUrl = url
            
            if let err = error {
                if manual { self.updateStatusMessage = "확인 실패: \(err)" }
            } else if available {
                self.updateStatusMessage = "새 버전(\(tag))이 있습니다!"
            } else {
                if manual { self.updateStatusMessage = "현재 최신 버전입니다 (v\(UpdateCheckerService.shared.currentVersion))." }
            }
        }
    }
    
    public func startSelfUpdate() {
        if isSelfUpdating { return }
        isSelfUpdating = true
        selfUpdateError = nil
        selfUpdateProgressText = "업데이트 준비 중..."
        
        SelfUpdateService.shared.performUpdate(
            tag: latestVersionTag,
            onProgress: { [weak self] msg in
                self?.selfUpdateProgressText = msg
            },
            onError: { [weak self] err in
                self?.isSelfUpdating = false
                self?.selfUpdateError = err
            }
        )
    }
}
