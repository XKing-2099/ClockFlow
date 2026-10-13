import SwiftUI

@main
@MainActor
struct HandscapeApp: App {
    @StateObject private var settings: ClockSettings

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let suiteName = "com.littlechange.Handscape.ui-testing"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            _settings = StateObject(wrappedValue: ClockSettings(defaults: defaults))
            return
        }
        #endif
        _settings = StateObject(wrappedValue: ClockSettings())
    }

    var body: some Scene {
        WindowGroup {
            ClockView(settings: settings)
        }
    }
}

