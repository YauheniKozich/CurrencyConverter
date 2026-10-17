//
//  CurrencyHelperTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 17.10.26.
//

import XCTest
@testable import CurrencyConverterTest

final class CurrencyHelperTests: XCTestCase {

    func testCurrencyFlagHelper_specialCodes() {
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "EUR"), "🇪🇺")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "USD"), "🇺🇸")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "GBP"), "🇬🇧")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "BTC"), "₿")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "ETH"), "Ξ")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "XAU"), "🪙")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "XAG"), "🪙")
    }

    func testCurrencyFlagHelper_isoStandardCodes() {
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "cad"), "🇨🇦")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "jpy"), "🇯🇵")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "chf"), "🇨🇭")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "aud"), "🇦🇺")
    }

    func testCurrencyFlagHelper_invalidOrEmptyCode_returnsGlobeFallback() {
        XCTAssertEqual(CurrencyFlagHelper.flag(for: ""), "🌐")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "X"), "🌐")
        XCTAssertEqual(CurrencyFlagHelper.flag(for: "1234"), "🌐")
    }

    func testCurrencyItem_initialization() {
        let item = CurrencyItem(code: "USD")
        XCTAssertEqual(item.code, "USD")
        XCTAssertEqual(item.id, "USD")
        XCTAssertEqual(item.flag, "🇺🇸")
        XCTAssertFalse(item.name.isEmpty)
    }

    func testCurrencyItem_withCustomName() {
        let customName = "United States Dollar"
        let item = CurrencyItem(code: "USD", customName: customName)
        XCTAssertEqual(item.name, customName)
    }

    func testCurrencyItem_hashableAndEquatable() {
        let item1 = CurrencyItem(code: "EUR")
        let item2 = CurrencyItem(code: "EUR")
        let item3 = CurrencyItem(code: "GBP")

        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
        XCTAssertEqual(item1.hashValue, item2.hashValue)
    }
}
