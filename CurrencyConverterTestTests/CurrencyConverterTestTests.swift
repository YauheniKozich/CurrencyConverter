//
//  CurrencyConverterTestTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 21.05.25.
//

import XCTest
@testable import CurrencyConverterTest
import SwiftData

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var handlers: [String: ((URLRequest) throws -> (HTTPURLResponse, Data))] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url?.absoluteString,
              let handler = MockURLProtocol.handlers[url] else {
            XCTFail("No handler for URL: \(request.url?.absoluteString ?? "unknown")")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class CurrencyAPIRepositoryTests: XCTestCase {
    var context: ModelContext!
    var repository: CurrencyAPIRepository!
    var testConfig: AppConfiguration!

    override func setUp() async throws {
        testConfig = try TestHelpers.makeTestConfiguration()

        let schema = Schema([Conversion.self, ExchangeRate.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let localDataSource: LocalCurrencyDataSource = CurrencyLocalDataSource(modelContainer: container)
        let networkService = NetworkService(session: session)

        repository = try CurrencyAPIRepository(
            localDataSource: localDataSource,
            networkService: networkService,
            apiKey: testConfig.apiKey,
            apiBaseURL: testConfig.apiBaseURL,
            cacheTTL: testConfig.cacheTTL
        )
    }

    override func tearDown() {
        repository = nil
        context = nil
        MockURLProtocol.handlers = [:]
        super.tearDown()
    }

    func testConvertSuccess() async throws {
        let jsonString = """
        {
            "meta": { "last_updated_at": "2025-05-20T12:00:00Z" },
            "data": {
                "EUR": { "code": "EUR", "value": 0.9 }
            }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let endpoint = CurrencyAPIEndpoint.convert(
            from: "USD",
            to: "EUR",
            apiKey: testConfig.apiKey,
            baseURL: testConfig.apiBaseURL
        )
        let url = try endpoint.makeURLRequest().url!.absoluteString

        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }

        let result = try await repository.convert(from: "USD", to: "EUR", amount: 10)
        XCTAssertEqual(result.rate, 0.9)
        XCTAssertEqual(result.result, 9.0, accuracy: 0.001)

        // Проверка кэширования
        let rates = try context.fetch(FetchDescriptor<ExchangeRate>())
        XCTAssertEqual(rates.count, 1, "Expected one cached rate")
        XCTAssertEqual(rates.first?.rate, 0.9, "Cached rate should match API response")
    }

    func testFetchSupportedCurrenciesSuccess() async throws {
        let jsonString = """
        {
            "data": {
                "USD": { "name": "US Dollar", "code": "USD" },
                "EUR": { "name": "Euro", "code": "EUR" }
            }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let endpoint = CurrencyAPIEndpoint.currencies(
            apiKey: testConfig.apiKey,
            baseURL: testConfig.apiBaseURL
        )
        let url = try endpoint.makeURLRequest().url!.absoluteString

        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }

        let currencies = try await repository.fetchSupportedCurrencies()
        XCTAssertEqual(currencies["USD"]?.name, "US Dollar")
        XCTAssertEqual(currencies["EUR"]?.code, "EUR")
    }

    func testFetchSupportedCurrenciesEmpty() async throws {
        let jsonString = """
        {
            "data": {}
        }
        """
        let data = jsonString.data(using: .utf8)!
        let endpoint = CurrencyAPIEndpoint.currencies(
            apiKey: testConfig.apiKey,
            baseURL: testConfig.apiBaseURL
        )
        let url = try endpoint.makeURLRequest().url!.absoluteString

        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }

        let currencies = try await repository.fetchSupportedCurrencies()
        XCTAssertTrue(currencies.isEmpty, "Expected empty currencies list")
    }
}
