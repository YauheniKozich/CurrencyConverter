//
//  ConvertCurrencyIntentTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 17.10.26.
//

import XCTest
import SwiftData
@testable import CurrencyConverterTest

@MainActor
final class ConvertCurrencyIntentTests: XCTestCase {
    var modelContainer: ModelContainer!
    var dependencies: AppDependencies!
    private var previousDependencies: AppDependencies?

    override func setUp() async throws {
        let schema = Schema([Conversion.self, ExchangeRate.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: config)

        let appConfig = try AppConfiguration(
            apiKey: "test_key",
            apiBaseURL: URL(string: "https://api.currencyapi.com/v3/")!,
            cacheTTL: 3600
        )
        dependencies = AppDependencies(config: appConfig, database: modelContainer)
        previousDependencies = AppDependencies.exchangeShared(dependencies)
    }

    override func tearDown() async throws {
        _ = AppDependencies.exchangeShared(previousDependencies)
        previousDependencies = nil
        dependencies = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testCancelledQueryDoesNotInvokeLoader() async throws {
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await CurrencyEntityQuery(loadCurrencies: {
                XCTFail("Already cancelled query must not load")
                return [:]
            }).entities(for: ["USD"])
        }
        do { _ = try await request.value; XCTFail("Expected cancellation") }
        catch is CancellationError {}
    }

    func testCancelledQueryStopsWaitingWhileAnotherQuerySucceeds() async throws {
        let started = expectation(description: "Query network started")
        let manager = CurrencyCacheManager(localDataSource: MockCurrencyLocalDataSource())
        let gate = QueryCatalogGate()
        let query = CurrencyEntityQuery(loadCurrencies: {
            try await manager.getCurrencies {
                started.fulfill()
                return await gate.value()
            }
        })
        let first = Task { try await query.entities(for: ["NOK"]) }
        await fulfillment(of: [started], timeout: 3)
        let second = Task { try await query.entities(for: ["NOK"]) }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while await manager.activeCurrencyConsumerCount != 2 {
            guard clock.now < deadline else {
                first.cancel(); second.cancel(); await gate.finish()
                XCTFail("Second query did not join"); return
            }
            await Task.yield()
        }
        first.cancel()
        let cancelled = expectation(description: "Query cancels before network finishes")
        let observer = Task { _ = await first.result; cancelled.fulfill() }
        let outcome = await XCTWaiter.fulfillment(of: [cancelled], timeout: 3)
        XCTAssertEqual(outcome, .completed)
        if outcome != .completed { await gate.finish() }
        await observer.value
        do { _ = try await first.value; XCTFail("Expected cancellation") }
        catch is CancellationError {}
        await gate.finish()
        let result = try await second.value
        XCTAssertEqual(result.map(\.id), ["NOK"])
    }

    private func makeQuery() -> CurrencyEntityQuery {
        let currencies = [
            "USD": Currency(code: "USD", name: "US Dollar"),
            "EUR": Currency(code: "EUR", name: "Euro"),
            "SGD": Currency(code: "SGD", name: "Singapore Dollar"),
            "NOK": Currency(code: "NOK", name: "Norwegian Krone")
        ]
        return CurrencyEntityQuery(loadCurrencies: { currencies })
    }

    func testEntityQueryResolvesDiskCatalogWhenOffline() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CurrencyLocalDataSource(modelContainer: modelContainer, cacheDirectoryURL: directory)
        try await source.saveCachedCurrencies([
            "SGD": Currency(code: "SGD", name: "Singapore Dollar"),
            "NOK": Currency(code: "NOK", name: "Norwegian Krone")
        ])
        let baseURL = try XCTUnwrap(URL(string: "https://currency-tests.invalid"))
        let endpoint = CurrencyAPIEndpoint.currencies(apiKey: "fixture", baseURL: baseURL)
        let url = try XCTUnwrap(endpoint.makeURLRequest().url?.absoluteString)
        MockURLProtocol.handlers[url] = { _ in throw URLError(.notConnectedToInternet) }
        defer { MockURLProtocol.handlers.removeValue(forKey: url) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let repository = try CurrencyAPIRepository(
            localDataSource: source, networkService: NetworkService(session: URLSession(configuration: configuration)),
            apiKey: "fixture", apiBaseURL: baseURL, cacheTTL: 0
        )
        let query = CurrencyEntityQuery(loadCurrencies: { try await repository.fetchSupportedCurrencies() })
        let entities = try await query.entities(for: ["SGD", "NOK"])
        XCTAssertEqual(entities.map(\.id), ["SGD", "NOK"])
    }

    func testFullCatalogIdentifiersAndSearch() async throws {
        let query = makeQuery()
        let entities = try await query.entities(for: ["usd", "EUR", "SGD", "NOK", "UNKNOWN"])
        XCTAssertEqual(entities.map(\.id), ["USD", "EUR", "SGD", "NOK"])
        let search = try await query.entities(matching: "norwegian")
        XCTAssertEqual(search.map(\.id), ["NOK"])
        let suggestions = try await query.suggestedEntities()
        XCTAssertFalse(suggestions.contains { $0.id == "SGD" })
    }

    func testUnavailableCatalogPropagatesErrorInsteadOfInventingEntities() async {
        let query = CurrencyEntityQuery(loadCurrencies: { throw AppError.networkUnavailable })
        do {
            _ = try await query.entities(for: ["SGD"])
            XCTFail("An unavailable network and cache must be reported")
        } catch let error as AppError {
            if case .networkUnavailable = error { return }
            XCTFail("Unexpected app error: \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEmptyCatalogDoesNotResolveUnsupportedIdentifiers() async throws {
        let query = CurrencyEntityQuery(loadCurrencies: { [:] })
        let entities = try await query.entities(for: ["USD", "NOK"])
        let suggestions = try await query.suggestedEntities()
        XCTAssertTrue(entities.isEmpty)
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testCurrencyEntityQuerySuggestedEntities() async throws {
        let query = makeQuery()
        let suggested = try await query.suggestedEntities()

        XCTAssertFalse(suggested.isEmpty)
        XCTAssertTrue(suggested.contains { $0.id == "USD" })
        XCTAssertTrue(suggested.contains { $0.id == "EUR" })
    }

    func testCurrencyEntityQueryEntitiesForIdentifiers() async throws {
        let query = makeQuery()
        let entities = try await query.entities(for: ["usd", "EUR", "UNKNOWN"])

        XCTAssertEqual(entities.count, 2)
        XCTAssertTrue(entities.contains { $0.id == "USD" })
        XCTAssertTrue(entities.contains { $0.id == "EUR" })
    }

    func testConvertCurrencyIntentInitialization() {
        let from = CurrencyEntity(id: "USD", name: "Доллар")
        let to = CurrencyEntity(id: "EUR", name: "Евро")
        let intent = ConvertCurrencyIntent(amount: 150.0, fromCurrency: from, toCurrency: to)

        XCTAssertEqual(intent.amount, 150.0)
        XCTAssertEqual(intent.fromCurrency.id, "USD")
        XCTAssertEqual(intent.toCurrency.id, "EUR")
    }

    func testConvertCurrencyIntentPerformWithCachedRate() async throws {
        // Записываем курс в базу данных
        let context = ModelContext(modelContainer)
        let rate = ExchangeRate(from: "USD", to: "EUR", rate: 0.92, timestamp: Date())
        context.insert(rate)
        try context.save()

        let from = CurrencyEntity(id: "USD", name: "Доллар США")
        let to = CurrencyEntity(id: "EUR", name: "Евро")
        let intent = ConvertCurrencyIntent(amount: 100.0, fromCurrency: from, toCurrency: to)

        let result = try await intent.perform()
        XCTAssertEqual(try XCTUnwrap(result.value), 92.0, accuracy: 0.001)

        // Проверяем, что конвертация записалась в историю SwiftData
        let historyActor = try ConversionHistoryActor(modelContainer: modelContainer)
        let history = try await historyActor.fetchHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.from, "USD")
        XCTAssertEqual(history.first?.to, "EUR")
        XCTAssertEqual(history.first?.amount, 100.0)
        XCTAssertEqual(history.first?.result, 92.0)
    }
}

private actor QueryCatalogGate {
    private var completed = false
    private var continuation: CheckedContinuation<[String: Currency], Never>?
    func value() async -> [String: Currency] {
        if completed { return ["NOK": Currency(code: "NOK", name: "Krone")] }
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish() {
        completed = true
        continuation?.resume(returning: ["NOK": Currency(code: "NOK", name: "Krone")])
        continuation = nil
    }
}
