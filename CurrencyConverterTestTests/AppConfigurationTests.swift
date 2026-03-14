//
//  AppConfigurationTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 21.05.25.
//

import XCTest
@testable import CurrencyConverterTest

final class AppConfigurationTests: XCTestCase {
    
    func testAppConfigurationInitialization_withTestValues() throws {
        let testURL = URL(string: "https://test.api.com")!
        let config = try AppConfiguration(
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

    func testAppConfigurationDefaultInitialization() throws {
        let config = try AppConfiguration(
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
    
    func testAppConfigurationInitialization_withEmptyAPIKey_throws() {
        let testURL = URL(string: "https://test.api.com")!
        
        XCTAssertThrowsError(
            try AppConfiguration(
                apiKey: "",
                apiBaseURL: testURL,
                cacheTTL: 3600,
                networkTimeout: 20
            )
        ) { error in
            XCTAssert(error is ConfigurationError)
            XCTAssertEqual((error as? ConfigurationError), .invalidAPIKey)
        }
    }
    
    func testConfigurationError_localizedDescription() {
        let configFileNotFound = ConfigurationError.configFileNotFound
        let invalidAPIKey = ConfigurationError.invalidAPIKey
        let invalidBaseURL = ConfigurationError.invalidBaseURL
        
        XCTAssertNotNil(configFileNotFound.errorDescription)
        XCTAssertNotNil(invalidAPIKey.errorDescription)
        XCTAssertNotNil(invalidBaseURL.errorDescription)
        
        XCTAssertNotNil(configFileNotFound.recoverySuggestion)
        XCTAssertNotNil(invalidAPIKey.recoverySuggestion)
        XCTAssertNotNil(invalidBaseURL.recoverySuggestion)
    }
}
