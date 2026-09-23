import XCTest

@MainActor final class SessionStorageTests: XCTestCase {
    func testAppCanStoreAndRetrieveSessionDataSecurely() {
        let app = XCUIApplication()
        app.launchArguments = ["--keychain-check"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Keychain storage verified"].waitForExistence(timeout: 15),
                      "Build the Simulator app with signing enabled so Keychain entitlements are present.")
    }
}
