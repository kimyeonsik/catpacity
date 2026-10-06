import Foundation
import IOKit.ps

public class PowerHelper {
    private static var runLoopSource: CFRunLoopSource?
    private static var powerChangeHandler: (() -> Void)?
    
    public static var hasBattery: Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        return !sources.isEmpty
    }
    
    public static var isOnBatteryPower: Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return false
        }
        if let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String? {
            return type == (kIOPSBatteryPowerValue as String)
        }
        if let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                   let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                    return state == (kIOPSBatteryPowerValue as String)
                }
            }
        }
        return false
    }
    
    public static var isLowPowerModeEnabled: Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    public static func startMonitoringPowerSource(onChange: @escaping () -> Void) {
        stopMonitoringPowerSource()
        powerChangeHandler = onChange
        
        let callback: IOPowerSourceCallbackType = { _ in
            DispatchQueue.main.async {
                PowerHelper.powerChangeHandler?()
            }
        }
        
        if let source = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
    
    public static func stopMonitoringPowerSource() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        powerChangeHandler = nil
    }
}

