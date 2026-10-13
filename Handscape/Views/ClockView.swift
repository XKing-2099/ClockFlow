import SwiftUI

@MainActor
struct ClockView: View {
    @ObservedObject var settings: ClockSettings
    @StateObject private var clock: ClockController
    @StateObject private var display = DisplaySession()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var controlsVisible = true
    @State private var settingsPresented = false
    @State private var autoHideTask: Task<Void, Never>?

    init(settings: ClockSettings) {
        self.settings = settings
        _clock = StateObject(wrappedValue: ClockController(preferences: settings.preferences))
    }

    var body: some View {
        GeometryReader { geometry in
            let stacked = geometry.size.width < geometry.size.height
            let viewport = ClockBoardViewport(
                width: geometry.size.width, height: geometry.size.height,
                stacked: stacked, immersive: !controlsVisible, showDate: settings.preferences.showDate,
                safeInsets: ClockSafeInsets(
                    top: geometry.safeAreaInsets.top, bottom: geometry.safeAreaInsets.bottom,
                    leading: geometry.safeAreaInsets.leading, trailing: geometry.safeAreaInsets.trailing
                )
            )

            ZStack {
                Color.black.ignoresSafeArea()

                ZStack {
                    if clock.transition != nil {
                        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                            clockCanvas(stacked: stacked, poses: clock.poses(at: ProcessInfo.processInfo.systemUptime))
                        }
                    } else {
                        clockCanvas(stacked: stacked, poses: clock.poses(at: ProcessInfo.processInfo.systemUptime))
                    }
                }
                .frame(width: viewport.width, height: viewport.height)
                // Keep the clock's gesture surface away from the controls below it.
                .contentShape(Rectangle())
                .onTapGesture { toggleControls() }
                .onLongPressGesture(minimumDuration: 0.7) { openSettings() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("当前时间")
                .accessibilityIdentifier("clock-display")
                .accessibilityValue(clock.reading.label + (clock.reading.period.map { " \($0)" } ?? ""))
                .accessibilityHint("轻点显示控制，长按打开设置")
                .accessibilityAction(named: "显示控制") { showControls() }
                .accessibilityAction(named: "打开设置") { openSettings() }
                .position(x: viewport.center.x + drift.width, y: viewport.center.y + drift.height)

                if let dateCenter = viewport.dateCenter {
                    Text(clock.displayedDate.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                        .font(.system(size: ClockBoardViewport.dateFontSize, weight: .medium))
                        .foregroundStyle(settings.preferences.palette.color.opacity(0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: viewport.width, height: ClockBoardViewport.dateHeight)
                        .accessibilityIdentifier("clock-date")
                        .position(x: dateCenter.x, y: dateCenter.y)
                        .allowsHitTesting(false)
                }

                if controlsVisible {
                    controls(stacked: stacked)
                        .transition(.opacity)
                }
            }
            .background(WindowScreenReader { screen in display.attach(to: screen) })
            .onAppear { clock.setLayout(stacked: stacked) }
            .onChange(of: stacked) { _, newValue in clock.setLayout(stacked: newValue) }
        }
        .background(.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(controlsVisible ? .automatic : .hidden)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $settingsPresented) {
            SettingsView(
                settings: settings,
                onDemonstrate: { preview(.minute) },
                onPreviewOccasion: { preview($0) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .preferredColorScheme(.dark)
        }
        .onAppear {
            clock.update(preferences: settings.preferences, systemReduceMotion: systemReduceMotion)
            applyScenePhase()
        }
        .onChange(of: scenePhase) { _, _ in applyScenePhase() }
        .onChange(of: settings.preferences) { _, newValue in
            clock.update(preferences: newValue, systemReduceMotion: systemReduceMotion)
            updateDisplay()
        }
        .onChange(of: systemReduceMotion) { _, newValue in
            clock.update(preferences: settings.preferences, systemReduceMotion: newValue)
        }
        .onChange(of: controlsVisible) { _, _ in updateDisplay() }
        .onChange(of: settingsPresented) { _, presented in
            if presented { autoHideTask?.cancel() } else { scheduleAutoHide() }
            updateDisplay()
        }
        .onDisappear {
            autoHideTask?.cancel()
            clock.deactivate()
            display.restore()
        }
    }

    private var drift: CGSize {
        let offset = ClockBoardDrift.offset(at: clock.displayedDate, enabled: settings.preferences.subtleDrift)
        return CGSize(width: offset.x, height: offset.y)
    }

    private func clockCanvas(stacked: Bool, poses: [HandPose]) -> some View {
        ClockCanvas(
            poses: poses, stacked: stacked,
            handColor: settings.preferences.palette.color, showFaces: settings.preferences.showFaces,
            faceFill: settings.preferences.palette.faceFill,
            faceOutline: settings.preferences.palette.faceOutline
        )
    }

    private func controls(stacked: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("CLOCKFLOW")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(3.5)
                        .foregroundStyle(.white.opacity(0.76))
                    Text("让指针，重新组成时间。")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.32))
                }
                Spacer()
                Text("24 CLOCKS\n48 HANDS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.8)
                    .lineSpacing(4)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: stacked ? 12 : 22) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Circle().fill(settings.preferences.palette.color.opacity(0.65)).frame(width: 4, height: 4)
                        Text(clock.reading.label + (clock.reading.period.map { " \($0)" } ?? ""))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                    }
                    Text(controlsCaption)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.38))
                }
                .foregroundStyle(.white.opacity(0.8))

                Spacer(minLength: 4)

                controlButton(symbol: "play", label: "演示", accessibility: "立即演示指针编舞") {
                    clock.demonstrate()
                    scheduleAutoHide()
                }
                controlButton(symbol: "slider.horizontal.3", label: "设置", accessibility: "打开时钟设置") {
                    openSettings()
                }
                controlButton(symbol: "moon", label: "沉浸", accessibility: "隐藏界面并进入低亮度模式") {
                    hideControls()
                }
            }
        }
        .padding(.horizontal, stacked ? 26 : 36)
        .padding(.top, 20)
        .padding(.bottom, stacked ? 24 : 16)
    }

    private var controlsCaption: String {
        if clock.motionIsReduced { return "静态显示 · 轻点唤出控制" }
        if let movement = clock.transition, movement.occasion != .minute {
            return "\(movement.title) · 轻点隐藏控制"
        }
        return "\(settings.preferences.motion.title) · 轻点隐藏控制"
    }

    private func controlButton(symbol: String, label: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 17, weight: .regular))
                Text(label).font(.system(size: 9))
            }
            .foregroundStyle(.white.opacity(0.65))
            .frame(minWidth: 44, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    private func toggleControls() {
        if controlsVisible { hideControls() } else { showControls() }
    }

    private func showControls() {
        withAnimation(systemReduceMotion ? nil : .easeInOut(duration: 0.25)) { controlsVisible = true }
        scheduleAutoHide()
    }

    private func hideControls() {
        autoHideTask?.cancel()
        withAnimation(systemReduceMotion ? nil : .easeInOut(duration: 0.25)) { controlsVisible = false }
    }

    private func openSettings() {
        showControls()
        settingsPresented = true
    }

    private func preview(_ occasion: ChoreographyOccasion) {
        settingsPresented = false
        clock.demonstrate(occasion: occasion)
        showControls()
    }

    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--keep-controls-visible") { return }
        #endif
        guard controlsVisible, !settingsPresented, scenePhase == .active,
              !UIAccessibility.isVoiceOverRunning else { return }
        autoHideTask = Task {
            do { try await Task.sleep(nanoseconds: 8_000_000_000) } catch { return }
            guard !Task.isCancelled, !settingsPresented, !UIAccessibility.isVoiceOverRunning else { return }
            hideControls()
        }
    }

    private func applyScenePhase() {
        if scenePhase == .active {
            #if DEBUG
            let playIntro = !ProcessInfo.processInfo.arguments.contains("--skip-intro")
            #else
            let playIntro = true
            #endif
            clock.activate(systemReduceMotion: systemReduceMotion, playIntro: playIntro)
            scheduleAutoHide()
        } else {
            autoHideTask?.cancel()
            clock.deactivate()
        }
        updateDisplay()
    }

    private func updateDisplay() {
        display.configure(
            preferences: settings.preferences, active: scenePhase == .active,
            immersive: !controlsVisible && !settingsPresented
        )
    }
}

