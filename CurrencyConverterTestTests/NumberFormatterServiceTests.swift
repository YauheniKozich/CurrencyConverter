//
//  NumberFormatterServiceTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 21.05.25.
//

import XCTest
@testable import CurrencyConverterTest

@MainActor
final class NumberFormatterServiceTests: XCTestCase {
    var formatter: NumberFormatterService!

    override func setUp() {
        super.setUp()
        formatter = NumberFormatterService(locale: Locale(identifier: "en_US"))
    }

    override func tearDown() {
        formatter = nil
        super.tearDown()
    }

    func testFormat_withWholeNumber() {
        let result = formatter.format(123.0, decimals: 2)
        XCTAssertEqual(result, "123.00")
    }

    func testFormat_withDecimalPlaces() {
        let result = formatter.format(123.456, decimals: 2)
        XCTAssertEqual(result, "123.46")
    }

    func testFormat_withFourDecimalPlaces() {
        let result = formatter.format(1.23456, decimals: 4)
        XCTAssertEqual(result, "1.2346")
    }

    func testFormat_withZero() {
        let result = formatter.format(0.0, decimals: 2)
        XCTAssertEqual(result, "0.00")
    }

    func testParse_validInteger() {
        let result = formatter.parse("123")
        XCTAssertEqual(result, 123.0)
    }

    func testParse_validDecimal() {
        let result = formatter.parse("123.45")
        XCTAssertEqual(result, 123.45)
    }

    func testParse_withComma() {
        let result = formatter.parse("123,45")
        XCTAssertEqual(result, 123.45)
    }

    func testParse_invalidString() {
        let result = formatter.parse("abc")
        XCTAssertNil(result)
    }

    func testParse_emptyString() {
        let result = formatter.parse("")
        XCTAssertNil(result)
    }

    func testParse_negativeNumber() {
        let result = formatter.parse("-123.45")
        XCTAssertEqual(result, -123.45)
    }
}
