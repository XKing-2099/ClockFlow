import Foundation

/// Clockwise degrees, with zero at twelve o'clock. Kept independent of SwiftUI
/// so the same geometry can later be used in a widget or custom font.
struct HandPose: Equatable, Sendable {
    var first: Double
    var second: Double
    var emphasis: Double = 1

    static let parked = HandPose(first: 225, second: 225, emphasis: 0.22)
}

/// Shared measurements keep thicker rounded hands inside their circular dials.
enum ClockHandGeometry {
    static let dialRadius = 0.49
    static let strokeRatio = 0.11
    static let firstLengthRatio = 0.86
    static let secondLengthRatio = 0.88
}

struct ClockReading: Equatable, Sendable {
    let hour: Int
    let minute: Int
    let uses24HourTime: Bool
    let isPM: Bool

    init(date: Date, uses24HourTime: Bool = true, calendar: Calendar = .current) {
        let actualHour = calendar.component(.hour, from: date)
        hour = uses24HourTime ? actualHour : (actualHour % 12 == 0 ? 12 : actualHour % 12)
        minute = calendar.component(.minute, from: date)
        self.uses24HourTime = uses24HourTime
        isPM = actualHour >= 12
    }

    var digits: [Int] { [hour / 10, hour % 10, minute / 10, minute % 10] }
    var label: String { String(format: "%02d:%02d", hour, minute) }
    var period: String? { uses24HourTime ? nil : (isPM ? "PM" : "AM") }
    var poses: [HandPose] { digits.flatMap(ClockDigits.poses(for:)) }

    static func nextMinute(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .minute, for: date)?.end
            ?? date.addingTimeInterval(60)
    }
}

enum ClockDigits {
    private enum Stroke {
        case right, left, up, down, vertical
        case downRight, downLeft, upRight, upLeft, parked

        var pose: HandPose {
            switch self {
            case .right: return HandPose(first: 90, second: 90)
            case .left: return HandPose(first: 270, second: 270)
            case .up: return HandPose(first: 0, second: 0)
            case .down: return HandPose(first: 180, second: 180)
            case .vertical: return HandPose(first: 0, second: 180)
            case .downRight: return HandPose(first: 180, second: 90)
            case .downLeft: return HandPose(first: 270, second: 180)
            case .upRight: return HandPose(first: 0, second: 90)
            case .upLeft: return HandPose(first: 0, second: 270)
            case .parked: return .parked
            }
        }
    }

    // Six cells per digit, in row-major order: top pair, middle pair, bottom pair.
    // The familiar two-hand clock typography uses parked diagonals for blank cells.
    private static let glyphs: [[Stroke]] = [
        [.downRight, .downLeft, .vertical, .vertical, .upRight, .upLeft], // 0
        [.parked, .down, .parked, .vertical, .parked, .up],              // 1
        [.right, .downLeft, .downRight, .upLeft, .upRight, .left],       // 2
        [.right, .downLeft, .right, .upLeft, .right, .upLeft],           // 3
        [.down, .down, .upRight, .vertical, .parked, .up],               // 4
        [.downRight, .left, .upRight, .downLeft, .right, .upLeft],       // 5
        [.downRight, .left, .vertical, .downLeft, .upRight, .upLeft],    // 6
        [.right, .downLeft, .parked, .vertical, .parked, .up],           // 7
        [.downRight, .downLeft, .upRight, .upLeft, .upRight, .upLeft],   // 8
        [.downRight, .downLeft, .upRight, .vertical, .right, .upLeft]    // 9
    ]

    static func poses(for digit: Int) -> [HandPose] {
        precondition((0...9).contains(digit), "A clock digit must be between zero and nine")
        return glyphs[digit].map(\.pose)
    }
}

