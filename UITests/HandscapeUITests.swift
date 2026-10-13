import XCTest

final class HandscapeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        // Stop the full-screen scene before rotating the simulator for the next test.
        XCUIApplication().terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    func testSettingsAndChoreography() throws {
        let app = launchClock()
        let display = app.otherElements["clock-display"]
        XCTAssertTrue(display.waitForExistence(timeout: 10))
        XCTAssertTrue((display.value as? String ?? "").contains(":"))
        capture(app, name: "iPhone Portrait")

        app.buttons["打开时钟设置"].tap()
        XCTAssertTrue(app.navigationBars["时钟设置"].waitForExistence(timeout: 5))
        app.buttons["夜红指针"].tap()
        capture(app, name: "Green Switches with Red Palette")
        let wave = app.buttons["motion-wave"]
        scrollTo(wave, in: app)
        wave.tap()
        capture(app, name: "Settings")
        app.buttons["完成"].tap()
        XCTAssertTrue(display.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["波浪 · 轻点隐藏控制"].exists)
        app.buttons["立即演示指针编舞"].tap()
        capture(app, name: "Wave Choreography")
        XCTAssertTrue(display.exists)
    }

    func testImmersionCanBeExitedAndTimeFormatChanges() throws {
        let app = launchClock()
        let display = app.otherElements["clock-display"]
        XCTAssertTrue(display.waitForExistence(timeout: 10))
        let normalFrame = display.frame

        app.buttons["隐藏界面并进入低亮度模式"].tap()
        let controlsHidden = NSPredicate { _, _ in !app.buttons["打开时钟设置"].exists }
        expectation(for: controlsHidden, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        let enlarged = NSPredicate { _, _ in
            display.frame.width > normalFrame.width + 1 && display.frame.height > normalFrame.height + 20
        }
        expectation(for: enlarged, evaluatedWith: display)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(display.frame.width / display.frame.height, normalFrame.width / normalFrame.height, accuracy: 0.01)
        capture(app, name: "Immersive Clock")
        display.tap()
        XCTAssertTrue(app.buttons["打开时钟设置"].waitForExistence(timeout: 5))
        app.buttons["打开时钟设置"].tap()
        let formatSwitch = app.switches["24 小时制"]
        XCTAssertTrue(formatSwitch.waitForExistence(timeout: 5))
        // SwiftUI exposes the labeled row and its native UISwitch separately.
        // Tap the switch itself rather than the middle of the label's large row.
        let nativeSwitch = formatSwitch.switches.firstMatch
        if nativeSwitch.exists {
            nativeSwitch.tap()
        } else {
            formatSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        app.buttons["完成"].tap()
        let showsPeriod = NSPredicate { _, _ in
            let value = display.value as? String ?? ""
            return value.contains("AM") || value.contains("PM")
        }
        expectation(for: showsPeriod, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }

    func testTimeUpdatesAtTheNextMinute() throws {
        let app = launchClock()
        let display = app.otherElements["clock-display"]
        XCTAssertTrue(display.waitForExistence(timeout: 10))
        let initialValue = display.value as? String ?? ""
        let timeChanged = NSPredicate { _, _ in
            (display.value as? String ?? "") != initialValue
        }
        expectation(for: timeChanged, evaluatedWith: app)
        waitForExpectations(timeout: 65)
        capture(app, name: "Minute Boundary")
        XCTAssertTrue(app.buttons["打开时钟设置"].exists)
    }

    func testCelebrationPreviews() throws {
        let app = launchClock()
        app.buttons["打开时钟设置"].tap()
        let hour = app.buttons["preview-hour"]
        scrollTo(hour, in: app)
        hour.tap()
        let hourCaption = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "整点彩蛋")).firstMatch
        XCTAssertTrue(hourCaption.waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["clock-display"].exists)
        capture(app, name: "Hour Celebration")

        app.buttons["打开时钟设置"].tap()
        let tenMinute = app.buttons["preview-ten-minute"]
        scrollTo(tenMinute, in: app)
        tenMinute.tap()
        let tenMinuteCaption = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "十分钟彩蛋")).firstMatch
        XCTAssertTrue(tenMinuteCaption.waitForExistence(timeout: 5))
        capture(app, name: "Ten Minute Celebration")
    }

    func testRandomChoreographyCanBeSelectedAndRetained() throws {
        let app = launchClock()
        app.buttons["打开时钟设置"].tap()
        let random = app.buttons["motion-random"]
        scrollTo(random, in: app)
        random.tap()
        XCTAssertTrue(random.isSelected)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["随机 · 轻点隐藏控制"].waitForExistence(timeout: 5))
        app.buttons["立即演示指针编舞"].tap()
        XCTAssertTrue(app.otherElements["clock-display"].exists)
        app.buttons["打开时钟设置"].tap()
        scrollTo(random, in: app)
        XCTAssertTrue(random.isSelected)
        capture(app, name: "Random Choreography Selected")
    }

    func testDateDoesNotOverlapClockOrControls() throws {
        let app = launchClock()
        let landscape = XCUIDevice.shared.orientation.isLandscape
        if landscape {
            let rotated = NSPredicate { _, _ in app.frame.width > app.frame.height }
            expectation(for: rotated, evaluatedWith: app)
            waitForExpectations(timeout: 10)
        }
        app.buttons["打开时钟设置"].tap()
        let dateSwitch = app.switches["显示日期"]
        XCTAssertTrue(dateSwitch.waitForExistence(timeout: 5))
        let nativeSwitch = dateSwitch.switches.firstMatch
        if nativeSwitch.exists {
            nativeSwitch.tap()
        } else {
            dateSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        app.buttons["完成"].tap()
        let display = app.otherElements["clock-display"]
        let date = app.staticTexts["clock-date"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(date.frame.height, 20)
        let normalFrame = display.frame
        XCTAssertGreaterThan(date.frame.minY, display.frame.maxY + 8)
        XCTAssertLessThan(date.frame.maxY, app.buttons["打开时钟设置"].frame.minY - 8)
        capture(app, name: "Clock and Separate Date")

        app.buttons["隐藏界面并进入低亮度模式"].tap()
        let hidden = NSPredicate { _, _ in !app.buttons["打开时钟设置"].exists }
        expectation(for: hidden, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertGreaterThan(display.frame.width, normalFrame.width + 1)
        XCTAssertEqual(display.frame.width / display.frame.height, normalFrame.width / normalFrame.height, accuracy: 0.01)
        XCTAssertGreaterThan(date.frame.minY, display.frame.maxY + 8)
        XCTAssertLessThan(date.frame.maxY, app.frame.maxY - 8)
        if landscape {
            let left = display.frame.minX - app.frame.minX
            let right = app.frame.maxX - display.frame.maxX
            let top = display.frame.minY - app.frame.minY
            let bottom = app.frame.maxY - display.frame.maxY
            // Allow the minute-based ±3-point anti-retention drift.
            XCTAssertEqual(top, bottom, accuracy: 8)
            XCTAssertGreaterThanOrEqual(left, 0)
            XCTAssertGreaterThanOrEqual(right, 0)
        }
        capture(app, name: "Compact Immersion with Date")
    }

    func testDateDoesNotOverlapClockInLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        try testDateDoesNotOverlapClockOrControls()
    }

    func testMinuteDriftCanBeDisabled() throws {
        let app = launchClock()
        app.buttons["打开时钟设置"].tap()
        let driftSwitch = app.switches["轻微位移"]
        XCTAssertTrue(driftSwitch.waitForExistence(timeout: 5))
        let nativeSwitch = driftSwitch.switches.firstMatch
        let toggle = nativeSwitch.exists ? nativeSwitch : driftSwitch
        XCTAssertEqual(toggle.value as? String, "1")
        if nativeSwitch.exists {
            nativeSwitch.tap()
        } else {
            driftSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, "0")
        app.buttons["完成"].tap()
        XCTAssertTrue(app.otherElements["clock-display"].exists)
        app.buttons["打开时钟设置"].tap()
        XCTAssertTrue(driftSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        capture(app, name: "Minute Drift Disabled")
    }

    func testBrighterImmersiveBrightnessCanBeAdjustedAndRetained() throws {
        let app = launchClock()
        app.buttons["打开时钟设置"].tap()
        let slider = app.sliders["immersive-brightness-slider"]
        scrollTo(slider, in: app)
        let value = app.staticTexts["immersive-brightness-value"]
        XCTAssertEqual(value.label, "30%")
        capture(app, name: "Default 30 Percent Brightness")
        // SwiftUI exposes the raw brightness as the accessibility value rather
        // than a normalized slider value. Drag the actual thumb instead.
        let initialPosition = (ClockTestBrightness.defaultValue - ClockTestBrightness.lowerBound)
            / (ClockTestBrightness.upperBound - ClockTestBrightness.lowerBound)
        slider.coordinate(withNormalizedOffset: CGVector(dx: initialPosition, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)))
        let changed = NSPredicate { _, _ in
            (Int(value.label.replacingOccurrences(of: "%", with: "")) ?? 0) > 40
        }
        expectation(for: changed, evaluatedWith: value)
        waitForExpectations(timeout: 5)
        let selected = value.label
        let percentage = Int(selected.replacingOccurrences(of: "%", with: "")) ?? 0
        XCTAssertGreaterThan(percentage, 40)
        XCTAssertLessThanOrEqual(percentage, 80)
        capture(app, name: "Brighter Immersive Brightness")
        app.buttons["完成"].tap()
        app.buttons["隐藏界面并进入低亮度模式"].tap()
        let controlsHidden = NSPredicate { _, _ in !app.buttons["打开时钟设置"].exists }
        expectation(for: controlsHidden, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        app.otherElements["clock-display"].tap()
        XCTAssertTrue(app.buttons["打开时钟设置"].waitForExistence(timeout: 5))
        app.buttons["打开时钟设置"].tap()
        scrollTo(slider, in: app)
        XCTAssertEqual(value.label, selected)
    }

    private enum ClockTestBrightness {
        static let defaultValue = 0.30
        static let lowerBound = 0.04
        static let upperBound = 0.80
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
        XCTFail("Unable to scroll to \(element)")
    }

    private func launchClock() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keep-controls-visible", "--skip-intro"]
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
