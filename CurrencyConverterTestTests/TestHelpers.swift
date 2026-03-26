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
    static let jsonContentType = ["Content-Type": "application/json"]

    static let currencyConversionJSON = """
    {
        "meta": { "last_updated_at": "2025-05-20T12:00:00Z" },
        "data": {
            "EUR": { "code": "EUR", "value": 0.9 }
        }
    }
    """

    static let supportedCurrenciesJSON = """
    {
        "data": {
            "USD": { "name": "US Dollar", "code": "USD" },
            "EUR": { "name": "Euro", "code": "EUR" }
        }
    }
    """

    static let emptyCurrenciesJSON = """
    {
        "data": {}
    }
    """

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

    static func makeJSONResponse(
        url: URL,
        statusCode: Int = 200
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: jsonContentType
        )!
    }

    static func makeJSONData(_ jsonString: String) -> Data {
        Data(jsonString.utf8)
    }

    static func makeMockURLProtocolHandler(statusCode: Int = 200,
                                           jsonString: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data)) {
        return { request in
            let response = makeJSONResponse(url: request.url!, statusCode: statusCode)
            let data = makeJSONData(jsonString)
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
