import XCTest

@MainActor
final class PrototypeInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["reviewDate"].waitForExistence(timeout: 15))
    }

    override func tearDownWithError() throws {
        if let run = testRun, run.failureCount > 0 {
            print("FAILED UI TREE: " + app.debugDescription)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    func testTabsMetricsAndEveryRange() {
        app.tabBars.buttons["Trends"].tap()
        let selector = app.segmentedControls["trendMetric"]
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        for metric in ["Calories", "Training", "All", "Weight"] {
            selector.buttons[metric].tap()
            XCTAssertTrue(selector.buttons[metric].isSelected)
            if metric == "All" {
                XCTAssertTrue(app.descendants(matching: .any)["combinedTrends"].exists)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "Combined trends"
                shot.lifetime = .keepAlways
                add(shot)
            }
        }
        for range in ["1 week", "3 months", "6 months", "1 year", "4 weeks"] {
            app.buttons["trendRange"].tap()
            app.buttons[range].tap()
            XCTAssertTrue(app.buttons["trendRange"].label.contains(range))
        }
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["calorieBalanceChart"].exists)
        let histogram = XCTAttachment(screenshot: app.screenshot())
        histogram.name = "Calorie target histogram"
        histogram.lifetime = .keepAlways
        add(histogram)
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["reviewDate"].waitForExistence(timeout: 5))
    }

    func testTrainingAxisAcrossRanges() {
        app.tabBars.buttons["Trends"].tap()
        app.segmentedControls["trendMetric"].buttons["Training"].tap()
        for range in ["1 week", "4 weeks", "3 months", "6 months", "1 year"] {
            app.buttons["trendRange"].tap()
            app.buttons[range].tap()
            XCTAssertTrue(app.buttons["trendRange"].label.contains(range))
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Training axis - " + range
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    func testMenuGoalsAndSettings() {
        app.buttons["profileMenu"].tap()
        app.buttons["Goals"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "140 lb")).firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Connections")).firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["reviewDate"].waitForExistence(timeout: 5))
    }

    func testDateArrowsAndCalendarPeriods() {
        let original = app.buttons["reviewDate"].label
        app.buttons["Previous day"].tap()
        XCTAssertNotEqual(app.buttons["reviewDate"].label, original)
        app.buttons["Next day"].tap()
        XCTAssertEqual(app.buttons["reviewDate"].label, original)
        for period in ["Week", "Month", "Day"] {
            app.buttons["reviewDate"].tap()
            app.segmentedControls.buttons[period].tap()
            if period == "Week" {
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Select week of")).firstMatch.tap()
            }
            if period == "Day" { app.buttons["Jump to today"].tap() }
            app.buttons["Show \(period.lowercased())"].tap()
            XCTAssertTrue(app.buttons["Previous \(period.lowercased())"].waitForExistence(timeout: 5))
        }
    }

    func testTypedAndMockVoiceMeals() {
        app.buttons["Add meal"].tap()
        let field = app.descendants(matching: .any)["mealText"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Prototype test lunch")
        app.buttons["sendMeal"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Meal added")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Add meal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Prototype test lunch"].exists)
        app.buttons["Add meal"].tap()
        app.buttons["Insert sample dictation; no microphone recording"].tap()
        XCTAssertTrue(app.staticTexts["Sample dictation inserted"].exists)
        app.buttons["sendMeal"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Meal added")).firstMatch.waitForExistence(timeout: 8))
    }

    func testPhotoMealAndMealDetails() {
        app.buttons["Add meal from photo"].tap()
        let field = app.descendants(matching: .any)["photoContext"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Rice underneath the chicken")
        XCTAssertTrue(field.isHittable)
        let editing = XCTAttachment(screenshot: app.screenshot())
        editing.name = "Photo context with keyboard"
        editing.lifetime = .keepAlways
        add(editing)
        app.buttons["Done editing"].tap()
        app.buttons["Insert sample voice context; no recording"].tap()
        app.buttons["submitPhotoMeal"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Meal added")).firstMatch.waitForExistence(timeout: 8))
        app.buttons["Done"].tap()
        let meal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Photo meal")).firstMatch
        for _ in 0..<5 {
            if meal.isHittable { break }
            app.swipeUp()
        }
        meal.tap()
        XCTAssertTrue(app.staticTexts["Sample nutrition"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    func testPhotoSourcesAndGallery() {
        app.buttons["Add meal from photo"].tap()
        app.buttons["takeMealPhoto"].tap()
        XCTAssertTrue(app.alerts["Photo unavailable"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        app.buttons["chooseMealPhoto"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 30))
        photo.tap()
        XCTAssertTrue(app.staticTexts["Photo stays on this device · nutrition is a mock estimate"].waitForExistence(timeout: 20))
        let ready = expectation(for: NSPredicate(format: "isEnabled == true AND isHittable == true"), evaluatedWith: app.buttons["submitPhotoMeal"])
        wait(for: [ready], timeout: 10)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Selected meal photo"
        preview.lifetime = .keepAlways
        add(preview)
        app.buttons["submitPhotoMeal"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Meal added")).firstMatch.waitForExistence(timeout: 8))
        app.buttons["Done"].tap()
        let thumbnail = app.buttons["mealPhotoThumbnail"]
        for _ in 0..<4 {
            if thumbnail.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(thumbnail.exists)
        thumbnail.tap()
        XCTAssertTrue(app.navigationBars["Photo meal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images.matching(identifier: "Meal photo").firstMatch.exists)
        let gallery = XCTAttachment(screenshot: app.screenshot())
        gallery.name = "Gallery meal detail"
        gallery.lifetime = .keepAlways
        add(gallery)
        app.buttons["Done"].tap()
    }

    func testMockWeightEditing() {
        app.buttons["weightCheckIn"].tap()
        let field = app.textFields["mockWeight"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "146.5")
        app.buttons["Save sample weight"].tap()
        app.buttons["weightCheckIn"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "146.5")
        app.buttons["Cancel"].tap()
    }
}
