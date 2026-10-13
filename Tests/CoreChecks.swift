import Foundation

@main
struct CoreChecks {
    @MainActor
    static func main() {
        var assertions = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            assertions += 1
            precondition(condition(), message)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9))!
        var occasionCounts: [ChoreographyOccasion: Int] = [:]

        // Verify every minute in a complete day, including noon and midnight in 12-hour time.
        for minuteOfDay in 0..<1_440 {
            let date = midnight.addingTimeInterval(Double(minuteOfDay * 60))
            let reading24 = ClockReading(date: date, calendar: calendar)
            let reading12 = ClockReading(date: date, uses24HourTime: false, calendar: calendar)
            let hour = minuteOfDay / 60
            check(reading24.hour == hour, "Incorrect 24-hour hour")
            check(reading24.minute == minuteOfDay % 60, "Incorrect minute")
            check(reading24.poses.count == 24, "Each time must contain 24 clocks")
            check(reading12.hour == (hour % 12 == 0 ? 12 : hour % 12), "Incorrect 12-hour hour")
            check(reading12.isPM == (hour >= 12), "Incorrect AM/PM")
            check(reading24.digits.allSatisfy { (0...9).contains($0) }, "Invalid digit")
            let occasion = ChoreographyOccasion.at(date, calendar: calendar)
            let expected: ChoreographyOccasion = minuteOfDay % 60 == 0 ? .hour : (minuteOfDay % 10 == 0 ? .tenMinute : .minute)
            check(occasion == expected, "Hour must take priority over ten-minute event")
            occasionCounts[occasion, default: 0] += 1
            let drift = ClockBoardDrift.offset(at: date)
            check((-3...3).contains(drift.x) && (-2...2).contains(drift.y), "Minute drift must stay inside its advertised range")
            check(ClockBoardDrift.offset(at: date.addingTimeInterval(45)) == drift, "Clock must not drift continuously between minute boundaries")
            check(ClockBoardDrift.offset(at: date, enabled: false) == ClockPosition(x: 0, y: 0), "Disabling drift must fix the clock position")
        }
        check(occasionCounts[.hour] == 24, "Expected 24 hour celebrations")
        check(occasionCounts[.tenMinute] == 120, "Expected 120 ten-minute celebrations")
        check(occasionCounts[.minute] == 1_296, "Incorrect regular-minute count")
        var driftPositions = Set<String>()
        for minute in -70...70 {
            let drift = ClockBoardDrift.offset(at: Date(timeIntervalSince1970: Double(minute * 60)))
            check((-3...3).contains(drift.x) && (-2...2).contains(drift.y), "Pre-epoch drift must also remain bounded")
            driftPositions.insert("\(drift.x):\(drift.y)")
        }
        check(driftPositions.count == 35, "Drift should cover the small 7-by-5 offset grid")
        for unit in [20.0, 35, 50, 90, 130, 300] {
            let radius = unit * ClockHandGeometry.dialRadius
            let stroke = max(2, unit * ClockHandGeometry.strokeRatio)
            for length in [ClockHandGeometry.firstLengthRatio, ClockHandGeometry.secondLengthRatio] {
                check(radius * length + stroke / 2 < radius, "Thicker rounded hand caps must stay inside the face")
            }
        }
        check(ClockBoardViewport.dateFontSize == 18 && ClockBoardViewport.dateHeight >= 24, "Larger date text needs its own taller row")
        let justBeforeMidnight = midnight.addingTimeInterval(86_399.75)
        let next = ClockReading.nextMinute(after: justBeforeMidnight, calendar: calendar)
        check(abs(next.timeIntervalSince(midnight) - 86_400) < 0.000_001, "Midnight boundary failed")
        check(ClockReading(date: next, calendar: calendar).label == "00:00", "Midnight label failed")
        let exactMinute = midnight.addingTimeInterval(60)
        check(ClockReading.nextMinute(after: exactMinute, calendar: calendar) > exactMinute, "Boundary must advance")

        // Fractional-hour time zones and DST must use local calendar components.
        calendar.timeZone = TimeZone(identifier: "Asia/Kathmandu")!
        check(ClockReading(date: midnight, calendar: calendar).label == "05:45", "Fractional time zone failed")
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let formatter = ISO8601DateFormatter()
        let beforeDST = formatter.date(from: "2026-03-08T06:59:59Z")!
        let afterDST = ClockReading.nextMinute(after: beforeDST, calendar: calendar)
        check(ClockReading(date: afterDST, calendar: calendar).label == "03:00", "DST boundary failed")
        check(ChoreographyOccasion.at(afterDST, calendar: calendar) == .hour, "Local DST hour should celebrate")

        // The compact matrix must scale as a whole, with a separate date band.
        for (width, height) in [(393.0, 759.0), (420, 800), (320, 568), (852, 340), (800, 400), (768, 1_000), (1_100, 700)] {
            let stacked = width < height
            let insetCases = stacked
                ? [ClockSafeInsets(), ClockSafeInsets(top: 62, bottom: 34), ClockSafeInsets(top: 62)]
                : [ClockSafeInsets(), ClockSafeInsets(bottom: 21, leading: 59, trailing: 59), ClockSafeInsets(bottom: 21, leading: 62)]
          for insets in insetCases {
            let safeWidth = width - insets.leading - insets.trailing
            let safeHeight = height - insets.top - insets.bottom
            for showDate in [false, true] {
                let regular = ClockBoardViewport(width: safeWidth, height: safeHeight, stacked: stacked, immersive: false,
                                                 showDate: showDate, safeInsets: insets)
                let immersive = ClockBoardViewport(width: safeWidth, height: safeHeight, stacked: stacked, immersive: true,
                                                   showDate: showDate, safeInsets: insets)
                check(immersive.width > regular.width, "Immersion should enlarge the clock width")
                check(immersive.height > regular.height, "Immersion should uniformly enlarge the clock height")
                let layout = ClockBoardLayout(stacked: stacked)
                check(abs(layout.width / layout.height - immersive.width / immersive.height) < 0.000_001, "Immersion must preserve the original matrix aspect")
                check(abs(regular.width / regular.height - immersive.width / immersive.height) < 0.000_001, "Both modes must use exactly the same geometry")
                let left = immersive.center.x - immersive.width / 2 + insets.leading
                let right = width - (immersive.center.x + immersive.width / 2 + insets.leading)
                let top = immersive.center.y - immersive.height / 2 + insets.top
                let bottom = height - (immersive.center.y + immersive.height / 2 + insets.top)
                check(left >= insets.leading + 3.999_999, "Clock must clear the camera-side safe area and drift")
                check(right >= insets.trailing + 3.999_999, "Clock must clear the opposite safe edge and drift")
                check(top >= insets.top + 3.999_999 && bottom >= insets.bottom + 3.999_999, "Clock must remain within vertical safe bounds")
                let expectedUnit = min((safeWidth - 8) / layout.width,
                                       (safeHeight - 8 - (showDate ? ClockBoardViewport.dateGap + ClockBoardViewport.dateHeight : 0)) / layout.height)
                check(abs(immersive.width - layout.width * expectedUnit) < 0.000_001, "Immersion must use the largest uniform safe-area scale")
                for viewport in [regular, immersive] {
                    check(viewport.center.y - viewport.height / 2 >= viewport.contentTop + 1.999_999, "Clock must clear header/safe area and drift")
                    if let date = viewport.dateCenter {
                        let dateTop = date.y - ClockBoardViewport.dateHeight / 2
                        let dateBottom = date.y + ClockBoardViewport.dateHeight / 2
                        check(dateTop - (viewport.center.y + viewport.height / 2) >= 15.999_999, "Date must never overlap the clock")
                        check(dateBottom <= viewport.contentBottom + 0.000_001, "Date must clear controls and screen bottom")
                    } else {
                        check(viewport.center.y + viewport.height / 2 <= viewport.contentBottom + 0.000_001, "Clock must clear bottom controls")
                    }
                }
                let unit = immersive.width / layout.width
                let centers = (0..<24).map { layout.position(for: $0) }
                for index in centers.indices {
                    let position = centers[index]
                    check(position.x >= 0.5 && position.x <= layout.width - 0.5 + 0.000_001, "Clock outside x bounds")
                    check(position.y >= 0.5 && position.y <= layout.height - 0.5 + 0.000_001, "Clock outside y bounds")
                    check(unit * 0.49 * 2 < min(immersive.width, immersive.height), "Dial diameter outside viewport")
                    for other in (index + 1)..<24 {
                        check(hypot(position.x - centers[other].x, position.y - centers[other].y) >= 1.079_999, "Circles overlap")
                    }
                }
            }
          }
        }
        let edgePhone = ClockBoardViewport(width: 912 - 118, height: 420 - 21, stacked: false,
                                                immersive: true, showDate: true,
                                                safeInsets: ClockSafeInsets(bottom: 21, leading: 59, trailing: 59))
        let cameraGap = edgePhone.center.x - edgePhone.width / 2
        check(abs(cameraGap - 4) < 0.000_001, "Landscape clock must approach the camera safe boundary")
        check(edgePhone.width > 780, "Landscape clock must grow beyond the previous equal-border layout")
        let asymmetricPhone = ClockBoardViewport(width: 912 - 62, height: 420 - 21, stacked: false,
                                                 immersive: true, showDate: true,
                                                 safeInsets: ClockSafeInsets(bottom: 21, leading: 62))
        check(asymmetricPhone.width > edgePhone.width, "Camera-free opposite edge must not inherit the camera inset")

        for stacked in [false, true] {
            let layout = ClockBoardLayout(stacked: stacked)
            var positions = Set<String>()
            for index in 0..<24 {
                let position = layout.position(for: index)
                check(position.x >= 0.5 && position.x <= layout.width - 0.5 + 0.000_001, "Clock outside horizontal bounds")
                check(position.y >= 0.5 && position.y <= layout.height - 0.5 + 0.000_001, "Clock outside vertical bounds")
                positions.insert("\(position.x):\(position.y)")
            }
            check(positions.count == 24, "Clock centers overlap")
        }

        let glyphs = (0...9).map(ClockDigits.poses(for:))
        for left in 0..<10 {
            check(glyphs[left].count == 6, "Digit needs six clocks")
            for right in (left + 1)..<10 {
                check(glyphs[left] != glyphs[right], "Digit shapes must be distinct")
            }
        }

        // Test every style across wrap-around angles, intermediate frames, and interruptions.
        let from = (0..<24).map { index in
            HandPose(first: index % 2 == 0 ? 359 : -17, second: Double(index) * 15, emphasis: 0.22)
        }
        let to = [8, 9, 0, 1].flatMap(ClockDigits.poses(for:))
        func checkContinuity(_ plan: ChoreographyPlan, label: String, steps: Int = 1_000) {
            check(plan.poses(at: -1) == plan.from, "Start must be exact")
            check(plan.poses(at: plan.duration + 1) == plan.to, "End must be exact")
            var previous = plan.from
            for step in 1...steps {
                let poses = plan.poses(at: Double(step) / Double(steps) * plan.duration)
                for index in 0..<24 {
                    let pose = poses[index]
                    check(pose.first.isFinite && pose.second.isFinite, "Non-finite angle")
                    check((0...1).contains(pose.emphasis), "Invalid hand opacity")
                    for (a, b) in [(previous[index].first, pose.first), (previous[index].second, pose.second)] {
                        let delta = abs(Choreography.normalized(b - a + 180) - 180)
                        check(delta < 12, "Visible discontinuity in \(label)")
                    }
                }
                previous = poses
            }
            for boundary in plan.segments.dropFirst().map(\.startedAt) {
                let before = plan.poses(at: boundary - 0.000_001)
                let after = plan.poses(at: boundary + 0.000_001)
                for index in 0..<24 {
                    for (a, b) in [(before[index].first, after[index].first), (before[index].second, after[index].second)] {
                        check(abs(Choreography.normalized(b - a + 180) - 180) < 0.001, "Waypoint angle jumps")
                    }
                    check(abs(before[index].emphasis - after[index].emphasis) < 0.001, "Waypoint opacity jumps")
                }
            }
        }

        for stacked in [false, true] {
          for style in MotionStyle.allCases.filter({ $0 != .random }) {
            check(Choreography.sample(from: from, to: to, progress: -0.5, style: style) == from, "Start must be exact")
            check(Choreography.sample(from: from, to: to, progress: 1.5, style: style) == to, "End must be exact")
            let movement = ClockTransition(from: from, to: to, style: style, startedAt: 100, duration: 6, stacked: stacked)
            checkContinuity(movement.plan, label: style.rawValue)
            check(movement.poses(at: 99) == from, "Transition starts too early")
            check(movement.poses(at: 100 + movement.duration) == to, "Transition does not settle")
            let interrupted = movement.poses(at: 103)
            let restarted = ClockTransition(from: interrupted, to: from, style: style, startedAt: 103, duration: 3)
            check(restarted.poses(at: 103) == interrupted, "Interruption must preserve hand positions")
          }

          for occasion in [ChoreographyOccasion.tenMinute, .hour] {
            for duration in [3.0, 6, 12] {
                for pattern in CelebrationPattern.allCases {
                    let movement = ClockTransition(from: from, to: to, style: .wave, startedAt: 100,
                                                   duration: duration, stacked: stacked, occasion: occasion, celebration: pattern)
                    check(abs(movement.duration - duration - occasion.holdDuration) < 0.000_001, "Hold must be added to movement duration")
                    checkContinuity(movement.plan, label: "\(occasion)-\(pattern)", steps: 1_000)
                    let hold = movement.plan.pictureHold!
                    check(abs(hold.upperBound - hold.lowerBound - occasion.holdDuration) < 0.000_001, "Incorrect picture hold duration")
                    let held = movement.plan.poses(at: hold.lowerBound + 0.01)
                    check(movement.plan.poses(at: hold.upperBound - 0.01) == held, "Picture must remain genuinely still")
                    let expected = Choreography.patternPoses(pattern, stacked: stacked)
                    for index in 0..<24 {
                        check(abs(Choreography.normalized(held[index].first - expected[index].first + 180) - 180) < 0.000_001, "First hand did not reach picture")
                        check(abs(Choreography.normalized(held[index].second - expected[index].second + 180) - 180) < 0.000_001, "Second hand did not reach picture")
                        check(held[index].emphasis == 1, "Picture hands must all be visible")
                    }
                    let interrupted = movement.poses(at: 100 + hold.lowerBound + 0.5)
                    let restarted = ClockTransition(from: interrupted, to: to, style: .fan, startedAt: 500, duration: 3)
                    check(restarted.poses(at: 500) == interrupted, "Restart during celebration must preserve current pose")
                }
            }
          }
        }

        check(Set((-16..<16).map { Choreography.resolvedStyle(.automatic, sequence: $0) }).count == 8, "Automatic must include all eight dances")
        for sequence in -16..<16 {
            check(Choreography.resolvedStyle(.automatic, sequence: sequence) != Choreography.resolvedStyle(.automatic, sequence: sequence + 1), "Automatic must not immediately repeat")
            check(Choreography.resolvedStyle(.fan, sequence: sequence) == .fan, "Manual style must remain selected")
            check(Choreography.celebration(for: .minute, sequence: sequence) == nil, "Normal minutes must not celebrate")
            check(Choreography.celebration(for: .hour, sequence: sequence) == .bloom, "Hour must select bloom")
        }
        check(Set((0..<5).compactMap { Choreography.celebration(for: .tenMinute, sequence: $0) }).count == 5, "Ten-minute pictures must rotate")

        // Seeded RNGs make coverage and no-repeat checks reproducible.
        for seed: UInt64 in [0, 1, 42, UInt64.max] {
            var generator = SeededGenerator(state: seed)
            var previous: MotionStyle? = .fan
            var selected = Set<MotionStyle>()
            for sequence in 0..<512 {
                let style = Choreography.resolvedStyle(.random, sequence: sequence, excluding: previous, using: &generator)
                check(MotionStyle.dances.contains(style), "Random must select a concrete dance")
                check(style != previous, "Random must not repeat the previous minute dance")
                check(style != .automatic && style != .random, "Random must not select another selection mode")
                previous = style
                selected.insert(style)
            }
            check(selected.count == 8, "Seeded random draws must cover all eight dances")
        }
        let randomTransition = ClockTransition(from: from, to: to, style: .random, startedAt: 100, duration: 6)
        check(MotionStyle.dances.contains(randomTransition.style), "Transition must resolve random at creation")
        check(randomTransition.poses(at: 102.5) == randomTransition.poses(at: 102.5), "Sampling must never re-randomize a running transition")
        check(randomTransition.poses(at: 100 + randomTransition.duration) == to, "Random transition must settle to the correct time")

        let legacyJSON = Data(#"{"palette":"red","motion":"wave","animationDuration":9,"uses24HourTime":false,"showFaces":false,"showDate":true,"subtleDrift":false,"keepScreenAwake":true,"dimDisplay":false,"brightness":0.23,"reduceMotion":true}"#.utf8)
        let legacy = try! JSONDecoder().decode(ClockPreferences.self, from: legacyJSON)
        check(legacy.palette == .red && legacy.motion == .wave, "Upgrade must retain old palette and chosen dance")
        check(legacy.animationDuration == 9 && legacy.brightness == 0.23, "Upgrade must retain old durations and brightness")
        check(!legacy.uses24HourTime && !legacy.showFaces && legacy.showDate && legacy.reduceMotion, "Upgrade must retain existing toggles")
        check(legacy.milestoneChoreography, "New celebration preference must default on for existing users")
        check(try! JSONDecoder().decode(ClockPreferences.self, from: JSONEncoder().encode(legacy)) == legacy, "Preferences must round-trip")
        let defaults = ClockPreferences()
        check(defaults.motion == .automatic && defaults.milestoneChoreography, "New installs should enable rotating dances and celebrations")
        check(defaults.brightness == 0.30, "Immersive brightness should default to 30%")
        let oldDefaultJSON = Data(#"{"brightness":0.14,"palette":"red","motion":"random","showDate":true}"#.utf8)
        let upgraded = try! JSONDecoder().decode(ClockPreferences.self, from: oldDefaultJSON)
        check(upgraded.brightness == 0.30, "Existing 14% defaults must upgrade to the brighter baseline")
        check(upgraded.palette == .red && upgraded.motion == .random && upgraded.showDate, "Brightness migration must retain unrelated preferences")
        for customBrightness in [0.04, 0.08, 0.20, 0.23, 0.40, 0.60, 0.80] {
            let customJSON = Data("{\"brightness\":\(customBrightness)}".utf8)
            let custom = try! JSONDecoder().decode(ClockPreferences.self, from: customJSON).sanitized
            check(custom.brightness == customBrightness, "Custom brightness must survive migration and sanitization")
        }
        var lowBrightness = upgraded
        lowBrightness.brightness = 0.14
        check(try! JSONDecoder().decode(ClockPreferences.self, from: JSONEncoder().encode(lowBrightness)).brightness == 0.14,
              "Selecting 14% after migration must not trigger migration again")
        var bounds = defaults
        bounds.brightness = -1
        check(bounds.sanitized.brightness == 0.04, "Brightness must clamp to the slider's lower bound")
        bounds.brightness = 2
        check(bounds.sanitized.brightness == 0.80, "Brightness must clamp to the slider's new upper bound")
        let suiteName = "com.littlechange.Handscape.core-checks.\(UUID().uuidString)"
        let storedDefaults = UserDefaults(suiteName: suiteName)!
        defer { storedDefaults.removePersistentDomain(forName: suiteName) }
        storedDefaults.set(oldDefaultJSON, forKey: "handscape.preferences.v1")
        let savedSettings = ClockSettings(defaults: storedDefaults)
        check(savedSettings.preferences.brightness == 0.30, "Settings loading must apply migration")
        let migratedData = storedDefaults.data(forKey: "handscape.preferences.v1")!
        check(try! JSONDecoder().decode(ClockPreferences.self, from: migratedData) == savedSettings.preferences,
              "Settings loading must persist the migrated preferences immediately")
        savedSettings.preferences.brightness = 0.14
        check(ClockSettings(defaults: storedDefaults).preferences.brightness == 0.14, "Reopening must preserve a newly selected 14%")
        savedSettings.preferences.brightness = 0.60
        check(ClockSettings(defaults: storedDefaults).preferences.brightness == 0.60, "Brightness above the old 40% limit must persist")
        var randomPreferences = defaults
        randomPreferences.motion = .random
        check(try! JSONDecoder().decode(ClockPreferences.self, from: JSONEncoder().encode(randomPreferences)) == randomPreferences, "Random setting must persist")
        var invalid = defaults
        invalid.animationDuration = .nan
        invalid.brightness = .infinity
        check(invalid.sanitized.animationDuration == 6 && invalid.sanitized.brightness == 0.30, "Non-finite preferences must sanitize")

        print("PASS: \(assertions) checks — all 1,440 minutes, eight dances, no-repeat random selection, six celebration pictures, exact holds, compact scaling, safe/date layout, DST, interruptions, and preference migration.")
    }

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
    }
}

