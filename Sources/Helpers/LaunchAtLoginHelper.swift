import Foundation
import ServiceManagement

public enum LaunchAtLoginHelper {
    private static let userDefaultsKey = "catpacity_launch_at_login"
    
    /// Returns true if launch at login is enabled.
    /// Defaults to `true` if never explicitly configured by the user.
    public static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: userDefaultsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: userDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            sync(enable: newValue)
        }
    }
    
    /// Registers the default only on first setup. Existing OS choices survive relaunches.
    public static func setupInitialState() {
        setupInitialState(defaults: .standard, synchronize: sync)
    }

    static func setupInitialState(defaults: UserDefaults, synchronize: (Bool) -> Void) {
        // Re-registering an existing preference can undo a change in System Settings.
        // Explicit checkbox changes still synchronize through the isEnabled setter.
        guard defaults.object(forKey: userDefaultsKey) == nil else { return }
        defaults.set(true, forKey: userDefaultsKey)
        synchronize(true)
    }
    
    /// Synchronizes the state with macOS SMAppService
    public static func sync(enable: Bool) {
        guard #available(macOS 13.0, *) else { return }
        
        let bundlePath = Bundle.main.bundleURL.path
        // SMAppService requires the app to be in /Applications or ~/Applications
        guard bundlePath.hasPrefix("/Applications") || bundlePath.contains("/Applications/") else {
            NSLog("Catpacity: Skipping SMAppService registration outside Applications directory: \(bundlePath)")
            return
        }
        
        do {
            let service = SMAppService.mainApp
            if enable {
                if service.status != .enabled {
                    try service.register()
                    NSLog("Catpacity: SMAppService successfully registered as login item")
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                    NSLog("Catpacity: SMAppService successfully unregistered")
                }
            }
        } catch {
            NSLog("Catpacity: SMAppService error: \(error.localizedDescription)")
        }
    }
}
