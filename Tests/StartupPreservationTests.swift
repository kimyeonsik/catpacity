import Foundation

// Exercise the production startup functions without writing any preference domain
// or invoking an account service, timer, notification, or SMAppService operation.
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]
    var writes = 0

    init(_ values: [String: Any]) {
        self.values = values
        super.init(suiteName: "com.yeonsik.catpacity.startup-tests")!
    }

    override func object(forKey defaultName: String) -> Any? { values[defaultName] }
    override func set(_ value: Any?, forKey defaultName: String) {
        writes += 1
        values[defaultName] = value
    }
}

@main
private struct StartupPreservationTests {
    static func main() {
        let menuKey = "catpacity_menubar_mode"
        let loginKey = "catpacity_launch_at_login"
        let preserved: [String: Any] = [
            "catpacity_selected_breed": "black_cat",
            "catpacity_animation_speed": 2.5,
            "catpacity_show_codex": false,
            "catpacity_codex_api_key": "synthetic-test-only",
            "catpacity_claude_usage_cache": Data([1, 2, 3])
        ]
        var cases = 0
        for mode: Any in ["cat_only", "cat_twoline", "cat_dynamic", "text_only", "future_mode", "", 7] {
            for enabled in [false, true] {
                var initial = preserved
                initial[menuKey] = mode
                initial[loginKey] = enabled
                let defaults = MemoryDefaults(initial)
                for _ in 0..<2 {
                    AppState.initializeMenuBarPreference(defaults: defaults)
                    LaunchAtLoginHelper.setupInitialState(defaults: defaults) { _ in
                        preconditionFailure("Existing login preference must not register/unregister an OS item")
                    }
                }
                precondition(NSDictionary(dictionary: defaults.values).isEqual(to: initial),
                             "Startup must preserve all saved settings and credential/cache placeholders")
                precondition(defaults.writes == 0, "Existing preferences must not be rewritten")
                cases += 1
            }
        }

        let fresh = MemoryDefaults(preserved)
        var registrations: [Bool] = []
        for _ in 0..<2 {
            AppState.initializeMenuBarPreference(defaults: fresh)
            LaunchAtLoginHelper.setupInitialState(defaults: fresh) { registrations.append($0) }
        }
        var expected = preserved
        expected[menuKey] = "cat_twoline"
        expected[loginKey] = true
        precondition(NSDictionary(dictionary: fresh.values).isEqual(to: expected))
        precondition(fresh.writes == 2 && registrations == [true], "First setup defaults apply exactly once")
        cases += 1

        for enabled in [false, true] {
            var initial = preserved
            initial[loginKey] = enabled
            let defaults = MemoryDefaults(initial)
            AppState.initializeMenuBarPreference(defaults: defaults)
            LaunchAtLoginHelper.setupInitialState(defaults: defaults) { _ in
                preconditionFailure("Adding a missing menu mode must not change the OS login item")
            }
            initial[menuKey] = "cat_twoline"
            precondition(NSDictionary(dictionary: defaults.values).isEqual(to: initial))
            precondition(defaults.writes == 1)
            cases += 1
        }
        print("Startup preservation passed: \(cases) cases; existing settings unchanged, first setup idempotent, no real account or login-item access.")
    }
}
