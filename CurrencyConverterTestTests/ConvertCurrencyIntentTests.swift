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
        AppDependencies.setShared(dependencies)
    }

    override func tearDown() async throws {
        dependencies = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testCurrencyEntityQuerySuggestedEntities() async throws {
        let query = CurrencyEntityQuery()
        let suggested = try await query.suggestedEntities()

        XCTAssertFalse(suggested.isEmpty)
        XCTAssertTrue(suggested.contains { $0.id == "USD" })
        XCTAssertTrue(suggested.contains { $0.id == "EUR" })
    }

    func testCurrencyEntityQueryEntitiesForIdentifiers() async throws {
        let query = CurrencyEntityQuery()
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
