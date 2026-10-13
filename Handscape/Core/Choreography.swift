import Foundation

enum MotionStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic, random, orbit, wave, cascade, ripple, fan, braid, pendulum, vortex

    var id: String { rawValue }
    static let dances: [MotionStyle] = [.orbit, .wave, .cascade, .ripple, .fan, .braid, .pendulum, .vortex]

    var title: String {
        switch self {
        case .automatic: return "自动轮换"
        case .random: return "随机"
        case .orbit: return "对向旋转"
        case .wave: return "波浪"
        case .cascade: return "逐列流动"
        case .ripple: return "中心涟漪"
        case .fan: return "扇面展开"
        case .braid: return "交织丝带"
        case .pendulum: return "钟摆合奏"
        case .vortex: return "风车旋涡"
        }
    }

    var subtitle: String {
        switch self {
        case .automatic: return "每分钟换一套，依次演绎八种原创编舞。"
        case .random: return "每次随机挑选一套编舞，避免连续重复。"
        case .orbit: return "两根指针沿相反方向绕行，重新汇聚成时间。"
        case .wave: return "起伏的波浪短暂停留，再缓缓回到数字。"
        case .cascade: return "旋转从左向右传递，像一场安静的接力。"
        case .ripple: return "从中心展开，像涟漪一样向外传播。"
        case .fan: return "先收拢，再展开成左右对称的扇面。"
        case .braid: return "两组斜线交错翻转，织成流动的丝带。"
        case .pendulum: return "整组指针左右摇摆，最后轻轻归位。"
        case .vortex: return "风车逐层转动，在旋涡中重新组成时间。"
        }
    }

    var symbol: String {
        switch self {
        case .automatic: return "repeat"
        case .random: return "shuffle"
        case .orbit: return "arrow.triangle.2.circlepath"
        case .wave: return "water.waves"
        case .cascade: return "arrow.right"
        case .ripple: return "circle.dotted.circle"
        case .fan: return "sun.max"
        case .braid: return "point.3.connected.trianglepath.dotted"
        case .pendulum: return "metronome"
        case .vortex: return "hurricane"
        }
    }
}

enum ChoreographyOccasion: String, CaseIterable, Sendable {
    case minute, tenMinute, hour

    static func at(_ date: Date, calendar: Calendar = .current) -> ChoreographyOccasion {
        let minute = calendar.component(.minute, from: date)
        if minute == 0 { return .hour }
        return minute.isMultiple(of: 10) ? .tenMinute : .minute
    }

    var holdDuration: TimeInterval {
        switch self {
        case .minute: return 0
        case .tenMinute: return 1.5
        case .hour: return 2
        }
    }

    var title: String {
        switch self {
        case .minute: return "分钟编舞"
        case .tenMinute: return "十分钟彩蛋"
        case .hour: return "整点彩蛋"
        }
    }
}

enum CelebrationPattern: String, CaseIterable, Sendable {
    case bloom, diamond, pinwheel, ribbons, starburst, rosette

    var title: String {
        switch self {
        case .bloom: return "礼花绽放"
        case .diamond: return "菱形窗格"
        case .pinwheel: return "四叶风车"
        case .ribbons: return "镜面丝带"
        case .starburst: return "星芒阵列"
        case .rosette: return "花瓣合奏"
        }
    }
}

struct ClockTransition: Sendable {
    let id = UUID()
    let style: MotionStyle
    let occasion: ChoreographyOccasion
    let celebration: CelebrationPattern?
    let startedAt: TimeInterval
    let plan: ChoreographyPlan

    var duration: TimeInterval { plan.duration }
    var title: String {
        if let celebration { return "\(occasion.title) · \(celebration.title)" }
        return style.title
    }

    init(
        from: [HandPose], to: [HandPose], style: MotionStyle,
        startedAt: TimeInterval, duration: TimeInterval,
        stacked: Bool = false, occasion: ChoreographyOccasion = .minute,
        celebration: CelebrationPattern? = nil
    ) {
        self.style = Choreography.resolvedStyle(style, sequence: 0)
        self.occasion = occasion
        self.celebration = occasion == .minute ? nil : (celebration ?? .bloom)
        self.startedAt = startedAt
        self.plan = Choreography.makePlan(
            from: from, to: to, style: self.style, duration: duration,
            stacked: stacked, occasion: occasion, celebration: self.celebration
        )
    }

    func poses(at uptime: TimeInterval) -> [HandPose] {
        plan.poses(at: uptime - startedAt)
    }
}

/// Waypoints and unwrapped angles are calculated once, not on every frame.
/// Holding a picture is a constant-pose segment, not just slower movement.
struct ChoreographyPlan: Sendable {
    let from: [HandPose]
    let to: [HandPose]
    let segments: [ChoreographySegment]
    let duration: TimeInterval
    let pictureHold: ClosedRange<TimeInterval>?

    func poses(at elapsed: TimeInterval) -> [HandPose] {
        if elapsed <= 0 { return from }
        if elapsed >= duration { return to }
        let segment = segments.first { elapsed < $0.startedAt + $0.duration } ?? segments[segments.count - 1]
        return segment.poses(at: elapsed)
    }
}

struct ChoreographySegment: Sendable {
    let from: [HandPose]
    let to: [HandPose]
    let startedAt: TimeInterval
    let duration: TimeInterval
    let delays: [Double]
    let isHold: Bool

    func poses(at elapsed: TimeInterval) -> [HandPose] {
        if isHold { return from }
        let progress = Choreography.clamp((elapsed - startedAt) / duration)
        return from.indices.map { index in
            let local = Choreography.clamp((progress - delays[index]) / (1 - delays[index]))
            let eased = Choreography.ease(local)
            let start = from[index]
            let end = to[index]
            let prominence = Choreography.mix(start.emphasis, end.emphasis, eased)
            return HandPose(
                first: Choreography.mix(start.first, end.first, eased),
                second: Choreography.mix(start.second, end.second, eased),
                emphasis: min(1, prominence + sin(local * .pi) * 0.7)
            )
        }
    }
}

enum Choreography {
    static func resolvedStyle(
        _ style: MotionStyle, sequence: Int, excluding previous: MotionStyle? = nil
    ) -> MotionStyle {
        var generator = SystemRandomNumberGenerator()
        return resolvedStyle(style, sequence: sequence, excluding: previous, using: &generator)
    }

    static func resolvedStyle<Generator: RandomNumberGenerator>(
        _ style: MotionStyle, sequence: Int, excluding previous: MotionStyle? = nil,
        using generator: inout Generator
    ) -> MotionStyle {
        switch style {
        case .automatic:
            let count = MotionStyle.dances.count
            return MotionStyle.dances[(sequence % count + count) % count]
        case .random:
            let candidates = MotionStyle.dances.filter { $0 != previous }
            return candidates[Int.random(in: candidates.indices, using: &generator)]
        default: return style
        }
    }

    static func celebration(for occasion: ChoreographyOccasion, sequence: Int) -> CelebrationPattern? {
        switch occasion {
        case .minute: return nil
        case .hour: return .bloom
        case .tenMinute:
            let patterns: [CelebrationPattern] = [.diamond, .pinwheel, .ribbons, .starburst, .rosette]
            return patterns[(sequence % patterns.count + patterns.count) % patterns.count]
        }
    }

    // Random must resolve once before sampling; otherwise each frame could pick a new dance.
    // Use ClockTransition or makePlan once for a stable randomized animation.
    static func sample(
        from: [HandPose], to: [HandPose], progress: Double, style: MotionStyle,
        stacked: Bool = false
    ) -> [HandPose] {
        precondition(style != .random, "Resolve a random style once before stateless sampling")
        let plan = makePlan(from: from, to: to, style: style, duration: 6, stacked: stacked)
        return plan.poses(at: clamp(progress) * plan.duration)
    }

    static func makePlan(
        from: [HandPose], to: [HandPose], style: MotionStyle, duration: TimeInterval,
        stacked: Bool = false, occasion: ChoreographyOccasion = .minute,
        celebration: CelebrationPattern? = nil
    ) -> ChoreographyPlan {
        precondition(from.count == 24 && to.count == 24)
        let duration = duration.isFinite ? max(3, min(12, duration)) : 6
        var builder = PlanBuilder(from: from, to: to, stacked: stacked)

        if occasion != .minute {
            let pattern = celebration ?? .bloom
            if occasion == .hour {
                builder.move(to: patternPoses(.rosette, stacked: stacked, phase: -35),
                             duration: duration * 0.24, direction: .opposed, stagger: .centerOut)
                builder.move(to: patternPoses(pattern, stacked: stacked),
                             duration: duration * 0.26, direction: .shortest, stagger: .centerOut)
            } else {
                builder.move(to: patternPoses(pattern, stacked: stacked),
                             duration: duration * 0.45, direction: .opposed, stagger: .columns)
            }
            builder.hold(duration: occasion.holdDuration, featured: true)
            builder.move(to: to, duration: duration * (occasion == .hour ? 0.5 : 0.55),
                         direction: .opposed, turns: 1, stagger: .columns)
            return builder.finish()
        }

        switch resolvedStyle(style, sequence: 0) {
        case .automatic, .random: preconditionFailure("Selection modes must resolve to a concrete dance")
        case .orbit:
            builder.move(to: to, duration: duration, direction: .opposed, turns: 1)
        case .cascade:
            builder.move(to: to, duration: duration, direction: .opposed, turns: 1, stagger: .columns)
        case .wave:
            builder.move(to: wavePoses(stacked: stacked, phase: 0),
                         duration: duration * 0.42, direction: .opposed, stagger: .gentleColumns)
            builder.hold(duration: duration * 0.06)
            builder.move(to: to, duration: duration * 0.52, direction: .opposed, turns: 1)
        case .ripple:
            builder.move(to: patternPoses(.rosette, stacked: stacked),
                         duration: duration * 0.28, direction: .shortest, stagger: .centerOut)
            builder.move(to: patternPoses(.bloom, stacked: stacked),
                         duration: duration * 0.24, direction: .shortest, stagger: .centerOut)
            builder.hold(duration: duration * 0.08)
            builder.move(to: to, duration: duration * 0.4, direction: .opposed)
        case .fan:
            builder.move(to: Array(repeating: HandPose(first: 0, second: 0), count: 24),
                         duration: duration * 0.24, direction: .shortest)
            let fan = coordinates(stacked: stacked).map { point in
                HandPose(first: point.x * 80 - 32, second: point.x * 80 + 32)
            }
            builder.move(to: fan, duration: duration * 0.32, direction: .shortest, stagger: .centerOut)
            builder.hold(duration: duration * 0.08)
            builder.move(to: to, duration: duration * 0.36, direction: .opposed)
        case .braid:
            builder.move(to: wavePoses(stacked: stacked, phase: 0.5, crossed: true),
                         duration: duration * 0.25, direction: .shortest, stagger: .gentleColumns)
            builder.move(to: wavePoses(stacked: stacked, phase: .pi + 0.5, crossed: true),
                         duration: duration * 0.27, direction: .shortest, stagger: .gentleColumns)
            builder.hold(duration: duration * 0.08)
            builder.move(to: to, duration: duration * 0.4, direction: .opposed)
        case .pendulum:
            let left = coordinates(stacked: stacked).map { point in
                HandPose(first: -55 + point.x * 12, second: -25 + point.x * 12)
            }
            let right = coordinates(stacked: stacked).map { point in
                HandPose(first: 25 + point.x * 12, second: 55 + point.x * 12)
            }
            builder.move(to: left, duration: duration * 0.24, direction: .shortest)
            builder.move(to: right, duration: duration * 0.30, direction: .shortest, stagger: .gentleColumns)
            builder.move(to: to, duration: duration * 0.46, direction: .opposed)
        case .vortex:
            builder.move(to: patternPoses(.pinwheel, stacked: stacked),
                         duration: duration * 0.27, direction: .clockwise, stagger: .centerOut)
            builder.move(to: patternPoses(.pinwheel, stacked: stacked, phase: 90),
                         duration: duration * 0.27, direction: .clockwise, stagger: .centerOut)
            builder.hold(duration: duration * 0.06)
            builder.move(to: to, duration: duration * 0.4, direction: .clockwise)
        }
        return builder.finish()
    }

    /// Original angle fields generated for the actual 8×3 or 4×6 arrangement.
    static func patternPoses(
        _ pattern: CelebrationPattern, stacked: Bool, phase: Double = 0
    ) -> [HandPose] {
        let points = coordinates(stacked: stacked)
        return points.indices.map { index in
            let point = points[index]
            let radial = atan2(point.x, -point.y) * 180 / .pi
            let row = stacked ? (index / 12) * 3 + (index % 6) / 2 : (index % 6) / 2
            let column = stacked ? ((index / 6) % 2) * 2 + index % 2 : (index / 6) * 2 + index % 2
            let a: Double
            let b: Double
            switch pattern {
            case .bloom:
                a = radial - 26
                b = radial + 26
            case .diamond:
                // Mirrored chevrons make a repeated diamond lattice.
                a = ((row + column) % 2 == 0) ? 45 : 225
                b = ((row + column) % 2 == 0) ? 135 : 315
            case .pinwheel:
                a = Double((row % 2) * 2 + column % 2) * 90
                b = a + 90
            case .ribbons:
                a = 90 + sin(point.x * .pi * 1.4) * 48 * (point.y < 0 ? 1 : -1)
                b = a + 180
            case .starburst:
                a = ((row + column) % 2 == 0) ? 45 : -45
                b = a + 180
            case .rosette:
                let localX = Double(index % 2) - 0.5
                let localY = Double((index % 6) / 2) - 1
                let petal = atan2(localX, -localY) * 180 / .pi
                a = petal - 34
                b = petal + 34
            }
            return HandPose(first: a + phase, second: b + phase)
        }
    }

    private static func wavePoses(stacked: Bool, phase: Double, crossed: Bool = false) -> [HandPose] {
        coordinates(stacked: stacked).map { point in
            let angle = (crossed ? 90.0 : 45.0) + sin(point.x * .pi * 1.25 + point.y * 0.8 + phase) * 48
            return HandPose(first: angle, second: angle + (crossed ? 180 : 90))
        }
    }

    private static func coordinates(stacked: Bool) -> [ClockPosition] {
        let layout = ClockBoardLayout(stacked: stacked)
        return (0..<24).map { index in
            let point = layout.position(for: index)
            return ClockPosition(x: (point.x - layout.width / 2) / (layout.width / 2 - 0.5),
                                 y: (point.y - layout.height / 2) / (layout.height / 2 - 0.5))
        }
    }

    static func normalized(_ angle: Double) -> Double {
        let result = angle.truncatingRemainder(dividingBy: 360)
        return result < 0 ? result + 360 : result
    }

    fileprivate static func ease(_ value: Double) -> Double {
        let t = clamp(value)
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    fileprivate static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
    fileprivate static func mix(_ from: Double, _ to: Double, _ t: Double) -> Double { from + (to - from) * t }

    private enum Direction { case opposed, shortest, clockwise }
    private enum Stagger { case none, columns, gentleColumns, centerOut }

    private struct PlanBuilder {
        let from: [HandPose]
        let to: [HandPose]
        let stacked: Bool
        var current: [HandPose]
        var segments: [ChoreographySegment] = []
        var elapsed: TimeInterval = 0
        var pictureHold: ClosedRange<TimeInterval>?

        init(from: [HandPose], to: [HandPose], stacked: Bool) {
            self.from = from
            self.to = to
            self.stacked = stacked
            self.current = from
        }

        mutating func move(
            to target: [HandPose], duration: TimeInterval,
            direction: Direction, turns: Double = 0, stagger: Stagger = .none
        ) {
            let angles = current.indices.map { index in
                func unwrap(_ start: Double, _ end: Double, clockwise: Bool) -> Double {
                    switch direction {
                    case .shortest: return start + normalized(end - start + 180) - 180
                    case .clockwise: return start + normalized(end - start) + turns * 360
                    case .opposed:
                        return clockwise
                            ? start + normalized(end - start) + turns * 360
                            : start - normalized(start - end) - turns * 360
                    }
                }
                return HandPose(first: unwrap(current[index].first, target[index].first, clockwise: true),
                                second: unwrap(current[index].second, target[index].second, clockwise: false),
                                emphasis: target[index].emphasis)
            }
            let points = coordinates(stacked: stacked)
            let delays = points.map { point -> Double in
                switch stagger {
                case .none: return 0
                case .columns: return (point.x + 1) * 0.14 + (point.y + 1) * 0.035
                case .gentleColumns: return (point.x + 1) * 0.06
                case .centerOut: return hypot(point.x, point.y) / sqrt(2) * 0.24
                }
            }
            segments.append(ChoreographySegment(from: current, to: angles, startedAt: elapsed,
                                                duration: duration, delays: delays, isHold: false))
            current = angles
            elapsed += duration
        }

        mutating func hold(duration: TimeInterval, featured: Bool = false) {
            if featured { pictureHold = elapsed...(elapsed + duration) }
            segments.append(ChoreographySegment(from: current, to: current, startedAt: elapsed,
                                                duration: duration, delays: Array(repeating: 0, count: 24), isHold: true))
            elapsed += duration
        }

        func finish() -> ChoreographyPlan {
            ChoreographyPlan(from: from, to: to, segments: segments, duration: elapsed, pictureHold: pictureHold)
        }
    }
}

