//
//  APIKeyValidatorTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 17.10.26.
//

import XCTest
@testable import CurrencyConverterTest

@MainActor
final class APIKeyValidatorTests: XCTestCase {
    private var session: URLSession!
    private var networkService: NetworkService!
    private var validator: APIKeyValidator!
    private let baseURL = URL(string: "https://api.currencyapi.com/")!

    override func setUp() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        networkService = NetworkService(session: session)
        validator = APIKeyValidator(networkService: networkService, baseURL: baseURL)
        MockURLProtocol.handlers.removeAll()
    }

    override func tearDown() async throws {
        MockURLProtocol.handlers.removeAll()
        validator = nil
        networkService = nil
        session = nil
    }

    func testValidate_withEmptyKey_returnsInvalid() async {
        let result = await validator.validate(apiKey: "   ")
        guard case .invalid = result else {
            XCTFail("Expected .invalid for empty key, got \(result)")
            return
        }
    }

    func testValidate_withValidKeyAndQuotas_returnsValid() async {
        let statusURL = "https://api.currencyapi.com/v3/status"
        let json = """
        {
            "quotas": {
                "month": {
                    "total": 300,
                    "used": 15,
                    "remaining": 285
                }
            }
        }
        """.data(using: .utf8)!

        MockURLProtocol.handlers[statusURL] = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "valid_key_123")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let result = await validator.validate(apiKey: "valid_key_123")
        XCTAssertEqual(result, .valid(remainingQuota: 285))
    }

    func testValidate_withInvalidKey401_returnsInvalid() async {
        let statusURL = "https://api.currencyapi.com/v3/status"
        let json = """
        {
            "message": "Validation error: API key is invalid"
        }
        """.data(using: .utf8)!

        MockURLProtocol.handlers[statusURL] = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let result = await validator.validate(apiKey: "bad_key")
        guard case .invalid(let message) = result else {
            XCTFail("Expected .invalid for 401, got \(result)")
            return
        }
        XCTAssertEqual(message, String(localized: "Неверный API ключ (код 401)"))
    }

    func testValidate_withNetworkError_returnsNetworkError() async {
        let statusURL = "https://api.currencyapi.com/v3/status"

        MockURLProtocol.handlers[statusURL] = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let result = await validator.validate(apiKey: "any_key")
        guard case .networkError = result else {
            XCTFail("Expected .networkError for network failure, got \(result)")
            return
        }
    }
}
