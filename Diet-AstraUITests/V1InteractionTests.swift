import XCTest

@MainActor final class V1InteractionTests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--v1-ui-check"]
        app.launch()
        XCTAssertTrue(app.buttons["Review meal editor"].waitForExistence(timeout: 15))
    }
    func testMealReviewKeepsDraftWhenSignedOut() {
        app.buttons["Review meal editor"].tap()
        XCTAssertTrue(app.textFields["Food"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Food"].value as? String, "Rice")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "V1 meal review"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["Save"].tap()
        let error = app.staticTexts["Sign in again to continue."]
        for _ in 0..<5 { if error.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(error.exists)
        XCTAssertTrue(app.navigationBars["Review meal"].exists, "Failed save must retain the editor")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Review meal editor"].waitForExistence(timeout: 5))
    }
    func testWeightAndWorkoutValidation() {
        app.buttons["Review weight editor"].tap()
        XCTAssertTrue(app.textFields["Weight"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Sign in again to continue."].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.buttons["Review workout editor"].tap()
        XCTAssertTrue(app.textFields["Exercise name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        app.textFields["Exercise name"].tap(); app.textFields["Exercise name"].typeText("Squat")
        XCTAssertTrue(app.buttons["Save"].isEnabled)
        app.buttons["Save"].tap()
        for _ in 0..<4 { if app.staticTexts["Sign in again to continue."].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Sign in again to continue."].exists)
        app.buttons["Cancel"].tap()
    }
    func testHealthShowsMissingDataAndSetupWithoutClaimingAccess() {
        app.buttons["Review Apple Health"].tap()
        XCTAssertTrue(app.navigationBars["Apple Health"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Apple Health is not connected."].exists)
        XCTAssertFalse(app.buttons["Connect Apple Health"].isEnabled, "Signed-out harness must not request device data")
        let missingSteps = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Steps", "No data")).firstMatch
        for _ in 0..<3 { if missingSteps.exists { break }; app.swipeUp() }
        XCTAssertTrue(missingSteps.exists, "Missing Health values must not be shown as zero")
        for _ in 0..<4 {
            if app.staticTexts["No readable workouts for this day."].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["No readable workouts for this day."].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Apple Health empty activity and setup"; shot.lifetime = .keepAlways; add(shot)
        for _ in 0..<4 {
            if app.buttons["Weight history and trends"].isHittable { break }
            app.swipeUp()
        }
        app.buttons["Weight history and trends"].tap()
        XCTAssertTrue(app.navigationBars["Weight journal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No measurements yet"].exists)
    }
    func testPhotoAndDictationReviewNavigation() {
        app.buttons["Review photo composer"].tap()
        XCTAssertTrue(app.buttons["takeMealPhoto"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Analyze and review"].isEnabled)
        app.buttons["takeMealPhoto"].tap()
        // Camera fallback is shown inline in the real composer.
        let fallback = app.staticTexts["Take photo requires a physical iPhone. In the simulator, choose a photo from the library instead."]
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
        app.buttons["Dictate"].tap()
        XCTAssertTrue(app.buttons["Start dictation"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        app.buttons["Close"].tap()
        app.buttons["Review goals"].tap()
        XCTAssertTrue(app.textFields["Target (lb)"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "V1 goals"; shot.lifetime = .keepAlways; add(shot)
    }
}
