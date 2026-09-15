import XCTest

@MainActor final class YomuUITests: XCTestCase {
    private func launch(appearance: String = "light") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["YOMU_TEST_STORE"] = UUID().uuidString
        app.launchArguments = ["-appearance", appearance]
        app.launch()
        XCTAssertTrue(app.buttons["Start reading"].waitForExistence(timeout: 15))
        return app
    }
    private func capture(_ name: String) {
        #if targetEnvironment(macCatalyst)
        let attachment = XCTAttachment(screenshot: XCUIApplication().windows.firstMatch.screenshot())
        #else
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        #endif
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func beginReading(_ app: XCUIApplication) {
        app.buttons["Start reading"].tap()
        XCTAssertTrue(app.buttons["Begin reading"].waitForExistence(timeout: 10))
        capture("session-setup")
        app.buttons["Begin reading"].tap()
        XCTAssertTrue(app.buttons["Pause reading"].waitForExistence(timeout: 10))
        app.buttons["Pause reading"].tap()
    }

    func testReadingSessionProducesQuizAndPersistsActivity() {
        let app = launch()
        capture("library")
        beginReading(app)
        capture("reader")
        XCTAssertTrue(app.buttons["Resume automatic reading"].exists)
        app.buttons["Next page"].tap()
        app.buttons["Finish session and start quiz"].tap()
        XCTAssertTrue(app.buttons["quiz.choice.1"].waitForExistence(timeout: 15))
        capture("quiz")
        for _ in 0..<10 {
            XCTAssertTrue(app.buttons["quiz.choice.1"].waitForExistence(timeout: 5))
            app.buttons["quiz.choice.1"].tap()
            let next = app.buttons["quiz.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        XCTAssertTrue(app.buttons["Back to your library"].waitForExistence(timeout: 5))
        capture("quiz-summary")
        app.buttons["Back to your library"].tap()
        XCTAssertTrue(app.buttons["Continue reading"].waitForExistence(timeout: 5))
        app.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["A week of little steps"].waitForExistence(timeout: 5))
        capture("activity")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Continue reading"].waitForExistence(timeout: 10))
    }

    func testNativeTextSelectionDictionaryAndSavedWord() {
        let app = launch()
        beginReading(app)
        let page = app.textViews.firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        page.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 55, dy: 28)).press(forDuration: 1.3)
        let lookup = app.buttons["Look up in Yomu"]
        if lookup.waitForExistence(timeout: 4) { lookup.tap() }
        else {
            XCTAssertTrue(app.buttons["Look up"].waitForExistence(timeout: 5))
            app.buttons["Look up"].tap()
        }
        XCTAssertTrue(app.buttons["Save word & highlight"].waitForExistence(timeout: 10))
        capture("dictionary")
        app.buttons["Save word & highlight"].tap()
        XCTAssertTrue(app.buttons["Saved to your words"].exists)
        app.buttons["Done"].tap()
        app.buttons["Reading session options"].tap()
        app.buttons["Save & close"].tap()
        app.buttons["Words"].tap()
        XCTAssertTrue(app.buttons["Practice your saved words"].waitForExistence(timeout: 5))
        capture("saved-words")
    }

    func testSettingsAndEmptyStates() {
        let app = launch()
        app.buttons["Words"].tap()
        XCTAssertTrue(app.staticTexts["Your first word is waiting."].waitForExistence(timeout: 5))
        app.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["A fresh beginning."].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Make it yours"].waitForExistence(timeout: 5))
        capture("settings")
        app.buttons["Done"].tap()
        app.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Start reading"].exists)
    }

    func testDarkModeLibraryAndReader() {
        let app = launch(appearance: "dark")
        capture("library-dark")
        beginReading(app)
        capture("reader-dark")
        XCTAssertTrue(app.buttons["Resume automatic reading"].exists)
        app.buttons["Reading settings"].tap()
        XCTAssertTrue(app.staticTexts["Make it comfortable"].waitForExistence(timeout: 5))
        capture("reader-settings-dark")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Resume automatic reading"].exists)
    }

    func testCompletedPageGoalResumesOnTheNextPage() {
        let app = launch()
        beginReading(app)
        app.buttons["Next page"].tap()
        app.buttons["Next page"].tap()
        app.buttons["Finish and quiz"].tap()
        XCTAssertTrue(app.buttons["quiz.choice.1"].waitForExistence(timeout: 15))
        app.buttons["Close"].tap()
        app.buttons["Finish quiz"].tap()
        XCTAssertTrue(app.buttons["Continue reading"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Page 4 of 6"].exists)
    }

    #if targetEnvironment(macCatalyst)
    func testMacNavigationImportPanelAndReading() {
        let app = launch()
        capture("mac-library")

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Your first word is waiting."].waitForExistence(timeout: 5))
        app.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["A fresh beginning."].waitForExistence(timeout: 5))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Make it yours"].waitForExistence(timeout: 5))
        app.buttons["Done"].click()
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Start reading"].waitForExistence(timeout: 5))

        app.typeKey("o", modifierFlags: .command)
        let cancelImport = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelImport.waitForExistence(timeout: 5))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        app.buttons["Start reading"].click()
        XCTAssertTrue(app.buttons["Begin reading"].waitForExistence(timeout: 5))
        app.buttons["Begin reading"].click()
        XCTAssertTrue(app.buttons["Pause reading"].waitForExistence(timeout: 10))
        app.buttons["Pause reading"].click()
        capture("mac-reader")
        app.buttons["Next page"].click()
        app.buttons["Finish session and start quiz"].click()
        XCTAssertTrue(app.buttons["quiz.choice.1"].waitForExistence(timeout: 15))
        app.buttons["quiz.choice.1"].click()
        XCTAssertTrue(app.buttons["quiz.next"].waitForExistence(timeout: 5))
        capture("mac-quiz")
    }
    #endif
}
