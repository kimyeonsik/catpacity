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
    
    /// Initializes and synchronizes login item status on app launch.
    public static func setupInitialState() {
        let isFirstTime = UserDefaults.standard.object(forKey: userDefaultsKey) == nil
        if isFirstTime {
            // Checkbox defaults to ON
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
        }
        
        if isEnabled {
            sync(enable: true)
        }
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
