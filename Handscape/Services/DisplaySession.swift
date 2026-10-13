import SwiftUI
import UIKit

/// Acquires display settings only while this clock is active, restoring the exact
/// previous settings on interruption, backgrounding, and dismissal.
@MainActor
final class DisplaySession: ObservableObject {
    private weak var screen: UIScreen?
    private var originalBrightness: CGFloat?
    private var originalIdleSetting: Bool?
    private var preferences = ClockPreferences()
    private var active = false
    private var immersive = false

    func attach(to newScreen: UIScreen) {
        if screen !== newScreen {
            restoreBrightness()
            screen = newScreen
        }
        apply()
    }

    func configure(preferences: ClockPreferences, active: Bool, immersive: Bool) {
        self.preferences = preferences.sanitized
        self.active = active
        self.immersive = immersive
        if active { apply() } else { restore() }
    }

    func restore() {
        active = false
        restoreBrightness()
        if let originalIdleSetting {
            UIApplication.shared.isIdleTimerDisabled = originalIdleSetting
        }
        originalIdleSetting = nil
    }

    private func apply() {
        guard active else { return }
        if originalIdleSetting == nil {
            originalIdleSetting = UIApplication.shared.isIdleTimerDisabled
        }
        UIApplication.shared.isIdleTimerDisabled = preferences.keepScreenAwake

        guard let screen else { return }
        if originalBrightness == nil { originalBrightness = screen.brightness }
        guard let originalBrightness else { return }

        let desired: CGFloat
        if immersive {
            desired = preferences.dimDisplay ? CGFloat(preferences.brightness) : originalBrightness
        } else {
            // Controls remain readable; the captured user brightness is restored on exit.
            let immersionBrightness = preferences.dimDisplay ? CGFloat(preferences.brightness) : originalBrightness
            desired = max(originalBrightness, immersionBrightness, 0.25)
        }
        if abs(screen.brightness - desired) > 0.003 { screen.brightness = desired }
    }

    private func restoreBrightness() {
        if let originalBrightness { screen?.brightness = originalBrightness }
        originalBrightness = nil
    }
}

/// Uses the actual window's display rather than the deprecated UIScreen.main.
struct WindowScreenReader: UIViewRepresentable {
    let onScreen: (UIScreen) -> Void

    func makeUIView(context: Context) -> ScreenProbe {
        let view = ScreenProbe()
        view.isUserInteractionEnabled = false
        view.onScreen = onScreen
        return view
    }

    func updateUIView(_ uiView: ScreenProbe, context: Context) {
        uiView.onScreen = onScreen
    }

    final class ScreenProbe: UIView {
        var onScreen: ((UIScreen) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let screen = window?.windowScene?.screen { onScreen?(screen) }
        }
    }
}

