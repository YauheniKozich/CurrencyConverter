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
    nonisolated(unsafe) static var handlers: [String: ((URLRequest) throws -> (HTTPURLResponse, Data))] = [:]

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

@MainActor
final class CurrencyAPIRepositoryTests: XCTestCase {
    var context: ModelContext!
    var repository: CurrencyAPIRepository!
    var testConfig: AppConfiguration!
    var testCacheDirectory: URL!

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

        testCacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: testCacheDirectory, withIntermediateDirectories: true)

        let localDataSource: any LocalCurrencyDataSource = CurrencyLocalDataSource(
            modelContainer: container,
            cacheDirectoryURL: testCacheDirectory
        )
        let networkService = NetworkService(session: session)

        repository = try CurrencyAPIRepository(
            localDataSource: localDataSource,
            networkService: networkService,
            apiKey: testConfig.apiKey,
            apiBaseURL: testConfig.apiBaseURL,
            cacheTTL: testConfig.cacheTTL
        )
    }

    override func tearDown() async throws {
        if let dir = testCacheDirectory {
            try? FileManager.default.removeItem(at: dir)
            testCacheDirectory = nil
        }
        repository = nil
        context = nil
        MockURLProtocol.handlers = [:]
        try await super.tearDown()
    }

    func testConvertSuccess() async throws {
        let endpoint = CurrencyAPIEndpoint.convert(
            from: "USD",
            to: "EUR",
            apiKey: testConfig.apiKey,
            baseURL: testConfig.apiBaseURL
        )
        let url = try endpoint.makeURLRequest().url!.absoluteString

        MockURLProtocol.handlers[url] = TestHelpers.makeMockURLProtocolHandler(
            jsonString: TestHelpers.currencyConversionJSON
        )

        let result = try await repository.convert(from: "USD", to: "EUR", amount: 10)
        XCTAssertEqual(result.rate, 0.9)
        XCTAssertEqual(result.result, 9.0, accuracy: 0.001)

        // Проверка кэширования
        let rates = try context.fetch(FetchDescriptor<ExchangeRate>())
        XCTAssertEqual(rates.count, 1, "Expected one cached rate")
        XCTAssertEqual(rates.first?.rate, 0.9, "Cached rate should match API response")
    }

    func testFetchSupportedCurrenciesSuccess() async throws {
        let endpoint = CurrencyAPIEndpoint.currencies(
            apiKey: testConfig.apiKey,
            baseURL: testConfig.apiBaseURL
        )
        let url = try endpoint.makeURLRequest().url!.absoluteString

        MockURLProtocol.handlers[url] = TestHelpers.makeMockURLProtocolHandler(
            jsonString: TestHelpers.supportedCurrenciesJSON
        )

        let currencies = try await repository.fetchSupportedCurrencies()
        XCTAssertEqual(currencies["USD"]?.name, "US Dollar")
        XCTAssertEqual(currencies["EUR"]?.code, "EUR")
    }

    func testFetchSupportedCurrenciesEmpty() async throws {
        let endpoint = CurrencyAPIEndpoint.currencies(
            apiKey: testConfig.apiKey,
            baseURL: testConfig.apiBaseURL
        )
        let url = try endpoint.makeURLRequest().url!.absoluteString

        MockURLProtocol.handlers[url] = TestHelpers.makeMockURLProtocolHandler(
            jsonString: TestHelpers.emptyCurrenciesJSON
        )

        let currencies = try await repository.fetchSupportedCurrencies()
        XCTAssertTrue(currencies.isEmpty, "Expected empty currencies list")
    }

    func testConvertOfflineFallbackWithStaleRate() async throws {
        // Pre-populate database with an expired rate
        let staleRate = ExchangeRate(
            from: "USD",
            to: "GBP",
            rate: 0.8,
            timestamp: Date().addingTimeInterval(-3600)
        )
        context.insert(staleRate)
        try context.save()

        // Mock network error
        let endpoint = CurrencyAPIEndpoint.convert(
            from: "USD",
            to: "GBP",
            apiKey: testConfig.apiKey,
            baseURL: testConfig.apiBaseURL
        )
        let url = try endpoint.makeURLRequest().url!.absoluteString
        MockURLProtocol.handlers[url] = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let result = try await repository.convert(from: "USD", to: "GBP", amount: 100)
        XCTAssertEqual(result.rate, 0.8)
        XCTAssertEqual(result.result, 80.0, accuracy: 0.001)
        XCTAssertTrue(result.isStaleRate, "Expected isStaleRate to be true for offline fallback")
    }

    func testFetchSupportedCurrencies_handlesAPI401Error() async throws {
        let endpoint = CurrencyAPIEndpoint.currencies(
            apiKey: testConfig.apiKey,
            baseURL: testConfig.apiBaseURL
        )
        let url = try endpoint.makeURLRequest().url!.absoluteString
        let errorJSON = "{\"message\":\"Invalid authentication credentials\"}"

        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, errorJSON.data(using: .utf8)!)
        }

        do {
            _ = try await repository.fetchSupportedCurrencies()
            XCTFail("Expected fetchSupportedCurrencies to throw on 401")
        } catch let error as AppError {
            if case .configurationError(let message) = error {
                XCTAssertTrue(message.contains("Invalid authentication credentials"))
            } else {
                XCTFail("Expected configurationError, got \(error)")
            }
        }
    }

    func testAppError_serverErrorLocalizedDescriptions() {
        let error401 = AppError.serverError(statusCode: 401)
        XCTAssertEqual(error401.localizedDescription, "Неверный или неактивный API-ключ")

        let error429 = AppError.serverError(statusCode: 429)
        XCTAssertEqual(error429.localizedDescription, "Превышен лимит запросов к CurrencyAPI")

        let customError = AppError.serverError(statusCode: 500, message: "Custom backend error")
        XCTAssertEqual(customError.localizedDescription, "Custom backend error")
    }
}
// MARK: - ConversionHistoryActor Tests

@MainActor
final class ConversionHistoryActorTests: XCTestCase {
    var container: ModelContainer!
    var historyActor: ConversionHistoryActor!

    override func setUp() async throws {
        try await super.setUp()
        container = try TestHelpers.makeInMemoryModelContainer()
        historyActor = try ConversionHistoryActor(modelContainer: container, maxEntries: 3)
    }

    override func tearDown() async throws {
        historyActor = nil
        container = nil
        try await super.tearDown()
    }

    func testSaveAndFetchHistory() async throws {
        try await historyActor.saveConversion(from: "USD", to: "EUR", amount: 10, result: 9, rate: 0.9)
        try await historyActor.saveConversion(from: "EUR", to: "GBP", amount: 20, result: 17, rate: 0.85)

        let history = try await historyActor.fetchHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].from, "EUR")
        XCTAssertEqual(history[1].from, "USD")
    }

    func testTrimmingHistoryWhenExceedingMaxEntries() async throws {
        for i in 1...5 {
            try await historyActor.saveConversion(
                from: "USD",
                to: "EUR",
                amount: Double(i),
                result: Double(i) * 0.9,
                rate: 0.9
            )
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let history = try await historyActor.fetchHistory()
        XCTAssertEqual(history.count, 3, "History should be trimmed to maxEntries (3)")
        XCTAssertEqual(history[0].amount, 5.0, "Most recent entry should be preserved")
        XCTAssertEqual(history[1].amount, 4.0)
        XCTAssertEqual(history[2].amount, 3.0)
    }

    func testDeleteConversion() async throws {
        try await historyActor.saveConversion(from: "USD", to: "EUR", amount: 10, result: 9, rate: 0.9)
        try await historyActor.saveConversion(from: "EUR", to: "GBP", amount: 20, result: 17, rate: 0.85)

        var history = try await historyActor.fetchHistory()
        XCTAssertEqual(history.count, 2)

        let idToDelete = history[0].id
        try await historyActor.deleteConversion(id: idToDelete)

        history = try await historyActor.fetchHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].from, "USD")
    }

    func testClearAllHistory() async throws {
        try await historyActor.saveConversion(from: "USD", to: "EUR", amount: 10, result: 9, rate: 0.9)
        try await historyActor.saveConversion(from: "EUR", to: "GBP", amount: 20, result: 17, rate: 0.85)

        try await historyActor.clearAllHistory()

        let history = try await historyActor.fetchHistory()
        XCTAssertTrue(history.isEmpty)
    }
}

