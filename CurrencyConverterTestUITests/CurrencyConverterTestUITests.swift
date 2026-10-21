//
//  CurrencyConverterTestUITests.swift
//  CurrencyConverterTestUITests
//
//  Created by Yauheni Kozich on 19.05.25.
//

import XCTest

final class CurrencyConverterTestUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testHistorySharesCSVFile() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-history", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let form = app.collectionViews.firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 10), app.debugDescription)
        let history = app.buttons["history.open"]
        // The history row can be below the viewport, especially in landscape.
        for _ in 0..<4 {
            if history.exists && history.isHittable { break }
            form.swipeUp()
        }
        XCTAssertTrue(history.exists && history.isHittable, app.debugDescription)
        history.tap()
        let export = app.buttons["history.export.csv"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        let saveToFiles = app.cells["Save to Files"]
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 10), app.debugDescription)
        saveToFiles.tap()
        let fileName = app.textFields.containing(
            NSPredicate(format: "value CONTAINS %@", "Conversion-History")
        ).firstMatch
        XCTAssertTrue(fileName.waitForExistence(timeout: 10), app.debugDescription)
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
