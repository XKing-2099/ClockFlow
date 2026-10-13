import SwiftUI

enum HandPalette: String, CaseIterable, Codable, Identifiable {
    case graphite, white, warm, red
    var id: String { rawValue }

    var title: String {
        switch self {
        case .graphite: return "石墨"
        case .white: return "纯白"
        case .warm: return "暖白"
        case .red: return "夜红"
        }
    }

    var color: Color {
        switch self {
        case .graphite: return Color(red: 245.0 / 255, green: 246.0 / 255, blue: 248.0 / 255)
        case .white: return Color(red: 0.94, green: 0.95, blue: 0.96)
        case .warm: return Color(red: 1, green: 0.86, blue: 0.67)
        case .red: return Color(red: 0.94, green: 0.26, blue: 0.21)
        }
    }

    var faceFill: Color {
        self == .graphite
            ? Color(red: 48.0 / 255, green: 52.0 / 255, blue: 59.0 / 255)
            : Color(white: 0.12)
    }

    var faceOutline: Color {
        self == .graphite
            ? Color(red: 85.0 / 255, green: 93.0 / 255, blue: 104.0 / 255)
            : color.opacity(0.24)
    }
}

struct ClockPreferences: Codable, Equatable {
    static let defaultBrightness = 0.30
    static let brightnessRange = 0.04...0.80
    private static let currentBrightnessVersion = 1

    var palette: HandPalette = .graphite
    var motion: MotionStyle = .automatic
    var milestoneChoreography = true
    var animationDuration: Double = 6
    var uses24HourTime = true
    var showFaces = true
    var showDate = false
    var subtleDrift = true
    var keepScreenAwake = true
    var dimDisplay = true
    var brightness: Double = ClockPreferences.defaultBrightness
    var reduceMotion = false
    private var brightnessVersion = ClockPreferences.currentBrightnessVersion

    init() {}

    private enum CodingKeys: String, CodingKey {
        case palette, motion, milestoneChoreography, animationDuration, uses24HourTime
        case showFaces, showDate, subtleDrift, keepScreenAwake, dimDisplay, brightness, reduceMotion, brightnessVersion
    }

    // Decode new fields independently so updating does not erase existing preferences.
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        palette = try values.decodeIfPresent(HandPalette.self, forKey: .palette) ?? palette
        motion = try values.decodeIfPresent(MotionStyle.self, forKey: .motion) ?? motion
        milestoneChoreography = try values.decodeIfPresent(Bool.self, forKey: .milestoneChoreography) ?? milestoneChoreography
        animationDuration = try values.decodeIfPresent(Double.self, forKey: .animationDuration) ?? animationDuration
        uses24HourTime = try values.decodeIfPresent(Bool.self, forKey: .uses24HourTime) ?? uses24HourTime
        showFaces = try values.decodeIfPresent(Bool.self, forKey: .showFaces) ?? showFaces
        showDate = try values.decodeIfPresent(Bool.self, forKey: .showDate) ?? showDate
        subtleDrift = try values.decodeIfPresent(Bool.self, forKey: .subtleDrift) ?? subtleDrift
        keepScreenAwake = try values.decodeIfPresent(Bool.self, forKey: .keepScreenAwake) ?? keepScreenAwake
        dimDisplay = try values.decodeIfPresent(Bool.self, forKey: .dimDisplay) ?? dimDisplay
        brightness = try values.decodeIfPresent(Double.self, forKey: .brightness) ?? brightness
        reduceMotion = try values.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? reduceMotion
        let savedBrightnessVersion = try values.decodeIfPresent(Int.self, forKey: .brightnessVersion) ?? 0
        // Upgrade only the old default. Preserve other custom values, and let a
        // user deliberately select 14% again after this one-time migration.
        if savedBrightnessVersion < Self.currentBrightnessVersion, abs(brightness - 0.14) < 0.000_001 {
            brightness = Self.defaultBrightness
        }
        brightnessVersion = max(savedBrightnessVersion, Self.currentBrightnessVersion)
    }

    var sanitized: ClockPreferences {
        var copy = self
        copy.animationDuration = animationDuration.isFinite ? min(12, max(3, animationDuration)) : 6
        copy.brightness = brightness.isFinite
            ? min(Self.brightnessRange.upperBound, max(Self.brightnessRange.lowerBound, brightness))
            : Self.defaultBrightness
        return copy
    }
}

@MainActor
final class ClockSettings: ObservableObject {
    private static let storageKey = "handscape.preferences.v1"
    private let defaults: UserDefaults

    @Published var preferences: ClockPreferences {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(ClockPreferences.self, from: data) {
            preferences = saved.sanitized
        } else {
            preferences = ClockPreferences()
        }
        // Persist the migration immediately, not only after the next UI edit.
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(preferences.sanitized) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

