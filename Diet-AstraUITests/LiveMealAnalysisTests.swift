import XCTest

/// Opt-in only: uses the signed-in Simulator account and makes one paid API request.
@MainActor final class LiveMealAnalysisTests: XCTestCase {
    func testTextAnalysisOpensEditableReviewWithoutSaving() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ASTRA_LIVE_AI_TEST"] == "1",
                          "Set TEST_RUNNER_ASTRA_LIVE_AI_TEST=1 only for an authorized live check.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Add meal"].waitForExistence(timeout: 20), "Sign in before running this check.")
        app.buttons["Add meal"].tap()
        let input = app.textFields["200g steak, rice and broccoli"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("200 g cooked white rice and 150 g grilled skinless chicken breast. No oil or sauce.")
        let analyze = app.buttons["Analyze and review"]
        if !analyze.isHittable { app.swipeUp() }
        analyze.tap()
        XCTAssertTrue(app.navigationBars["Review meal"].waitForExistence(timeout: 75), "Live analysis must return an editable review.")
        XCTAssertTrue(app.textFields["Food"].firstMatch.exists)
        let calories = app.textFields["Calories (kcal)"].firstMatch
        XCTAssertTrue(calories.exists)
        XCTAssertGreaterThan(Double((calories.value as? String ?? "").replacingOccurrences(of: ",", with: "")) ?? 0, 0)
        XCTAssertTrue(app.buttons["Save"].isEnabled)
        let title = app.textFields["Meal name"]
        title.tap()
        title.typeText(" - review check")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Live AI meal review (unsaved sample)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Analyze and review"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Add meal"].waitForExistence(timeout: 5))
    }
    func testPhotoAnalysisOpensEditableReviewWithoutSaving() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ASTRA_LIVE_AI_TEST"] == "1",
                          "Live analysis is opt-in.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Add meal from photo"].waitForExistence(timeout: 20))
        app.buttons["Add meal from photo"].tap()
        XCTAssertTrue(app.buttons["chooseMealPhoto"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Analyze and review"].isEnabled)
        app.buttons["chooseMealPhoto"].tap()
        let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,"))
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 30))
        guard let label = ProcessInfo.processInfo.environment["ASTRA_TEST_PHOTO_LABEL"] else {
            print("FIXTURE PHOTO CHOICES: " + photos.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Photo fixture selection"; shot.lifetime = .keepAlways; add(shot)
            throw XCTSkip("Inspect imported public fixture and supply TEST_RUNNER_ASTRA_TEST_PHOTO_LABEL.")
        }
        let fixture = app.images.matching(NSPredicate(format: "label == %@", label))
        XCTAssertEqual(fixture.count, 1, "Select only the uniquely identified public test fixture.")
        fixture.element.tap()
        XCTAssertTrue(app.images["Meal photo"].waitForExistence(timeout: 20))
        let analyze = app.buttons["Analyze and review"]
        for _ in 0..<4 { if analyze.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(analyze.isEnabled)
        analyze.tap()
        XCTAssertTrue(app.navigationBars["Review meal"].waitForExistence(timeout: 75))
        let food = app.textFields["Food"].firstMatch
        XCTAssertTrue(food.exists)
        XCTAssertFalse((food.value as? String ?? "").isEmpty)
        XCTAssertTrue(app.buttons["Save"].isEnabled)
        let calories = app.textFields["Calories (kcal)"].firstMatch
        XCTAssertGreaterThan(Double((calories.value as? String ?? "").replacingOccurrences(of: ",", with: "")) ?? 0, 0)
        app.textFields["Meal name"].tap()
        app.textFields["Meal name"].typeText(" - photo review check")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Live photo estimate (unsaved public fixture)"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Add meal from photo"].waitForExistence(timeout: 5))
    }

}
