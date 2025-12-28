//
//  NumberFormatterServiceTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 21.05.25.
//

import XCTest
@testable import CurrencyConverterTest

final class NumberFormatterServiceTests: XCTestCase {
    var formatter: NumberFormatterService!

    override func setUp() {
        super.setUp()
        // Используем фиксированную локаль для предсказуемого поведения
        formatter = NumberFormatterService(locale: Locale(identifier: "en_US"))
    }

    override func tearDown() {
        formatter = nil
        super.tearDown()
    }

    func testFormatDecimal_withWholeNumber() {
        let result = formatter.formatDecimal(123.0, maximumFractionDigits: 2)
        XCTAssertEqual(result, "123")
    }

    func testFormatDecimal_withDecimalPlaces() {
        let result = formatter.formatDecimal(123.456, maximumFractionDigits: 2)
        XCTAssertEqual(result, "123.46")
    }

    func testFormatDecimal_withFourDecimalPlaces() {
        let result = formatter.formatDecimal(1.23456, maximumFractionDigits: 4)
        XCTAssertEqual(result, "1.2346")
    }

    func testFormatDecimal_withZero() {
        let result = formatter.formatDecimal(0.0, maximumFractionDigits: 2)
        XCTAssertEqual(result, "0")
    }

    func testParseDecimal_validInteger() {
        let result = formatter.parseDecimal("123")
        XCTAssertEqual(result, 123.0)
    }

    func testParseDecimal_validDecimal() {
        let result = formatter.parseDecimal("123.45")
        XCTAssertEqual(result, 123.45)
    }

    func testParseDecimal_withComma() {
        let result = formatter.parseDecimal("123,45")
        XCTAssertEqual(result, 123.45)
    }

    func testParseDecimal_invalidString() {
        let result = formatter.parseDecimal("abc")
        XCTAssertNil(result)
    }

    func testParseDecimal_emptyString() {
        let result = formatter.parseDecimal("")
        XCTAssertNil(result)
    }

    func testParseDecimal_negativeNumber() {
        let result = formatter.parseDecimal("-123.45")
        XCTAssertEqual(result, -123.45)
    }
}
