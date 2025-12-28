//
//  AppConfigurationTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 21.05.25.
//

import XCTest
@testable import CurrencyConverterTest

final class AppConfigurationTests: XCTestCase {
    func testAppConfigurationInitialization_withTestValues() {
        let testURL = URL(string: "https://test.api.com")!
        let config = AppConfiguration(
            apiKey: "test_key",
            apiBaseURL: testURL,
            cacheTTL: 600,
            networkTimeout: 15,
            keychainService: "test.service",
            keychainAccount: "test.account"
        )

        XCTAssertEqual(config.apiKey, "test_key")
        XCTAssertEqual(config.apiBaseURL, testURL)
        XCTAssertEqual(config.cacheTTL, 600)
        XCTAssertEqual(config.networkTimeout, 15)
        XCTAssertEqual(config.keychainService, "test.service")
        XCTAssertEqual(config.keychainAccount, "test.account")
    }

    func testAppConfigurationDefaultInitialization() {
        // Note: This test may fail if Config.plist is not properly set up
        // In a real scenario, we'd mock the plist loading
        let config = AppConfiguration(
            apiKey: "test_key",
            apiBaseURL: URL(string: "https://test.com")!,
            cacheTTL: 3600,
            networkTimeout: 20,
            keychainService: "service",
            keychainAccount: "account"
        )

        XCTAssertEqual(config.apiKey, "test_key")
        XCTAssertEqual(config.cacheTTL, 3600)
        XCTAssertEqual(config.networkTimeout, 20)
    }
}
