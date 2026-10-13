import Combine
import Foundation
import UIKit

@MainActor
final class ClockController: ObservableObject {
    @Published private(set) var reading: ClockReading
    @Published private(set) var displayedDate: Date
    @Published private(set) var transition: ClockTransition?

    private var settledPoses: [HandPose]
    private var preferences: ClockPreferences
    private var systemReduceMotion = false
    private var active = false
    private var hasStarted = false
    private var stacked = false
    private var demonstrationIndex = 0
    private var lastMinuteStyle: MotionStyle?
    private var minuteTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(preferences: ClockPreferences) {
        self.preferences = preferences
        let date = Date()
        let initialReading = ClockReading(date: date, uses24HourTime: preferences.uses24HourTime)
        reading = initialReading
        displayedDate = date
        settledPoses = initialReading.poses

        // Time-zone changes and manual clock adjustments should never leave stale digits.
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification),
            NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            Task { @MainActor in
                guard let self, self.active else { return }
                self.synchronize(animated: false)
                self.scheduleNextMinute()
            }
        }
        .store(in: &subscriptions)
    }

    var motionIsReduced: Bool { systemReduceMotion || preferences.reduceMotion }

    func activate(systemReduceMotion: Bool, playIntro: Bool = true) {
        self.systemReduceMotion = systemReduceMotion
        guard !active else { return }
        active = true
        if !hasStarted && playIntro && !motionIsReduced {
            settledPoses = Array(repeating: .parked, count: 24)
        }
        synchronize(animated: !hasStarted && playIntro)
        hasStarted = true
        scheduleNextMinute()
    }

    func deactivate() {
        active = false
        minuteTask?.cancel()
        minuteTask = nil
        completionTask?.cancel()
        completionTask = nil
        transition = nil
    }

    func update(preferences: ClockPreferences, systemReduceMotion: Bool) {
        let oldFormat = self.preferences.uses24HourTime
        self.preferences = preferences.sanitized
        self.systemReduceMotion = systemReduceMotion
        if active && (oldFormat != preferences.uses24HourTime || motionIsReduced) {
            synchronize(animated: false)
        }
    }

    func setLayout(stacked: Bool) {
        guard self.stacked != stacked else { return }
        self.stacked = stacked
        // A rotating device should immediately regain a readable time layout.
        if active { synchronize(animated: false) }
    }

    func demonstrate(occasion: ChoreographyOccasion = .minute) {
        guard active else { return }
        demonstrationIndex += 1
        synchronize(animated: true, occasion: occasion, demonstrationOffset: demonstrationIndex)
    }

    func poses(at uptime: TimeInterval) -> [HandPose] {
        transition?.poses(at: uptime) ?? settledPoses
    }

    private func synchronize(
        animated: Bool, occasion: ChoreographyOccasion = .minute, demonstrationOffset: Int = 0
    ) {
        let date = Date()
        let nextReading = ClockReading(date: date, uses24HourTime: preferences.uses24HourTime)
        let uptime = ProcessInfo.processInfo.systemUptime
        let currentPoses = poses(at: uptime)
        completionTask?.cancel()
        completionTask = nil
        reading = nextReading
        displayedDate = date
        settledPoses = nextReading.poses

        guard animated && !motionIsReduced else {
            transition = nil
            return
        }

        let minuteIndex = Int(floor(date.timeIntervalSince1970 / 60))
        // Select only once per actual minute dance. Milestone pictures do not consume
        // a random choice or change the previous dance used for repeat prevention.
        let selectedStyle: MotionStyle
        if occasion == .minute {
            selectedStyle = Choreography.resolvedStyle(
                preferences.motion, sequence: minuteIndex + demonstrationOffset, excluding: lastMinuteStyle
            )
            lastMinuteStyle = selectedStyle
        } else {
            selectedStyle = lastMinuteStyle ?? .orbit
        }
        let movement = ClockTransition(
            from: currentPoses, to: nextReading.poses,
            style: selectedStyle,
            startedAt: uptime, duration: preferences.animationDuration, stacked: stacked, occasion: occasion,
            celebration: Choreography.celebration(for: occasion, sequence: minuteIndex / 10 + demonstrationOffset)
        )
        transition = movement
        completionTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(movement.duration * 1_000_000_000))
            } catch { return }
            guard let self, !Task.isCancelled, self.transition?.id == movement.id else { return }
            self.transition = nil
            self.completionTask = nil
        }
    }

    private func scheduleNextMinute() {
        minuteTask?.cancel()
        minuteTask = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let boundary = ClockReading.nextMinute(after: now)
                let delay = max(0.01, boundary.timeIntervalSinceNow)
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch { return }
                guard let self, self.active, !Task.isCancelled else { return }
                // Read the wall clock again after sleeping: suspension can delay a wake-up.
                let next = ClockReading(date: Date(), uses24HourTime: self.preferences.uses24HourTime)
                if next != self.reading {
                    let occasion = self.preferences.milestoneChoreography
                        ? ChoreographyOccasion.at(Date()) : .minute
                    self.synchronize(animated: true, occasion: occasion)
                }
            }
        }
    }
}

