//
//  TestHelpers.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation
import SwiftData
@testable import CurrencyConverterTest

/// Вспомогательные функции для тестирования
enum TestHelpers {
    static func makeTestConfiguration() throws -> AppConfiguration {
        let testURL = URL(string: "https://api.test.com")!
        return try AppConfiguration(
            apiKey: "test_api_key",
            apiBaseURL: testURL,
            cacheTTL: 300,
            networkTimeout: 10,
            keychainService: "com.test.currencyconverter",
            keychainAccount: "TestAPIKey"
        )
    }

    static func makeInMemoryModelContainer() throws -> ModelContainer {
        let schema = Schema([Conversion.self, ExchangeRate.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeMockURLProtocolHandler(statusCode: Int = 200,
                                           jsonString: String,
                                           url: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data)) {
        return { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            let data = jsonString.data(using: .utf8)!
            return (response, data)
        }
    }
}

// MARK: - Mock Implementations

class MockKeychainHelper {
    var storedValues: [String: String] = [:]

    func saveString(_ string: String, service: String, account: String) {
        storedValues["\(service)_\(account)"] = string
    }

    func readString(service: String, account: String) -> String? {
        return storedValues["\(service)_\(account)"]
    }

    func delete(service: String, account: String) {
        storedValues.removeValue(forKey: "\(service)_\(account)")
    }
}
