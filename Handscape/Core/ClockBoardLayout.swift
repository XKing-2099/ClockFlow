import Foundation

struct ClockPosition: Equatable, Sendable {
    let x: Double
    let y: Double
}

/// Optional minute-based movement, independent of digit changes and choreography.
enum ClockBoardDrift {
    static func offset(at date: Date, enabled: Bool = true) -> ClockPosition {
        guard enabled else { return ClockPosition(x: 0, y: 0) }
        let minute = Int(floor(date.timeIntervalSince1970 / 60))
        let x = ((minute % 7) * 3 % 7 + 7) % 7
        let y = ((minute % 5) * 2 % 5 + 5) % 5
        return ClockPosition(x: Double(x) - 3, y: Double(y) - 2)
    }
}

struct ClockBoardLayout: Sendable {
    let stacked: Bool
    private let pitch = 1.08
    private let digitGap = 0.24
    private let hourGap = 0.28
    private let stackGap = 0.56

    var width: Double {
        stacked ? pitch * 3 + digitGap + 1 : pitch * 7 + digitGap * 3 + hourGap + 1
    }

    var height: Double {
        stacked ? pitch * 5 + stackGap + 1 : pitch * 2 + 1
    }

    func position(for index: Int) -> ClockPosition {
        precondition((0..<24).contains(index))
        let digit = index / 6
        let row = (index % 6) / 2
        let column = index % 2
        if stacked {
            return ClockPosition(
                x: 0.5 + Double((digit % 2) * 2 + column) * pitch + Double(digit % 2) * digitGap,
                y: 0.5 + Double((digit / 2) * 3 + row) * pitch + Double(digit / 2) * stackGap
            )
        }
        return ClockPosition(
            x: 0.5 + Double(digit * 2 + column) * pitch
                + Double(digit) * digitGap + (digit >= 2 ? hourGap : 0),
            y: 0.5 + Double(row) * pitch
        )
    }
}

struct ClockSafeInsets: Sendable {
    var top: Double = 0
    var bottom: Double = 0
    var leading: Double = 0
    var trailing: Double = 0
}

/// Input size is the safe content area; centers are returned in that same space.
/// Only one scale is applied to the entire fixed clock matrix in either mode.
struct ClockBoardViewport: Sendable {
    let width: Double
    let height: Double
    let center: ClockPosition
    let dateCenter: ClockPosition?
    let contentTop: Double
    let contentBottom: Double
    static let dateFontSize = 18.0
    static let dateHeight = 26.0
    static let dateGap = 16.0
    static let immersivePadding = 4.0

    init(
        width: Double, height: Double, stacked: Bool, immersive: Bool, showDate: Bool,
        safeInsets: ClockSafeInsets = ClockSafeInsets()
    ) {
        let layout = ClockBoardLayout(stacked: stacked)
        let dateBand = showDate ? Self.dateGap + Self.dateHeight : 0
        let topReserve = stacked ? 76.0 : 70.0
        let bottomReserve = stacked ? 88.0 : 82.0
        let screenWidth = width + safeInsets.leading + safeInsets.trailing
        let screenHeight = height + safeInsets.top + safeInsets.bottom
        let symmetricSafeWidth = screenWidth - max(safeInsets.leading, safeInsets.trailing) * 2
        let availableWidth = max(1, min(width, symmetricSafeWidth) - (stacked ? 44 : 72))
        let availableHeight = max(1, height - topReserve - bottomReserve - dateBand - 16)
        let normalUnit = min(availableWidth / layout.width, availableHeight / layout.height)

        if immersive {
            // Fill the actual safe area, including asymmetric space next to the camera.
            // A four-point buffer covers the optional ±3/±2-point pixel drift.
            let padding = Self.immersivePadding
            let unit = min(
                max(1, width - padding * 2) / layout.width,
                max(1, height - padding * 2 - dateBand) / layout.height
            )
            self.width = layout.width * unit
            self.height = layout.height * unit
            // Prefer the physical screen center, but move away from the camera or
            // date band when needed instead of sacrificing the available scale.
            self.center = ClockPosition(
                x: min(max(screenWidth / 2 - safeInsets.leading, padding + self.width / 2),
                       width - padding - self.width / 2),
                y: min(max(screenHeight / 2 - safeInsets.top, padding + self.height / 2),
                       height - padding - dateBand - self.height / 2)
            )
            self.contentTop = 1
            self.contentBottom = height - 1
        } else {
            self.width = layout.width * normalUnit
            self.height = layout.height * normalUnit
            let regionHeight = max(1, height - topReserve - bottomReserve)
            let groupTop = topReserve + (regionHeight - self.height - dateBand) / 2
            self.center = ClockPosition(x: width / 2, y: groupTop + self.height / 2)
            self.contentTop = topReserve
            self.contentBottom = height - bottomReserve
        }

        if showDate {
            self.dateCenter = ClockPosition(x: center.x, y: center.y + self.height / 2 + Self.dateGap + Self.dateHeight / 2)
        } else {
            self.dateCenter = nil
        }
    }
}

