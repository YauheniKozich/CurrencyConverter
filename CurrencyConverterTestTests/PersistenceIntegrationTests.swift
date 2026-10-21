//
//  PersistenceIntegrationTests.swift
//  CurrencyConverterTestTests
//
//  Created by Codex on 21.10.26.
//

import XCTest
import SwiftData
@testable import CurrencyConverterTest

@MainActor
final class PersistenceIntegrationTests: XCTestCase {
    private func makeContainer(at url: URL, writable: Bool = true) throws -> ModelContainer {
        let schema = Schema([Conversion.self, ExchangeRate.self])
        let configuration = ModelConfiguration(
            schema: schema, url: url, allowsSave: writable, cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func seed(at url: URL) async throws {
        let container = try makeContainer(at: url)
        let rates = CurrencyLocalDataSource(modelContainer: container)
        try await rates.saveRate(from: "USD", to: "EUR", rate: 0.9)
        let history = try ConversionHistoryActor(modelContainer: container)
        try await history.saveConversion(from: "USD", to: "EUR", amount: 10, result: 9, rate: 0.9)
        try await history.saveConversion(from: "EUR", to: "GBP", amount: 20, result: 17, rate: 0.85)
    }

    private func expectFailure(_ operation: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        var didFail = false
        do {
            try await operation()
        } catch {
            didFail = true
        }
        XCTAssertTrue(didFail, "A read-only persistent store must reject the save", file: file, line: line)
    }

    func testPersistentRatesSurviveReopenAndConcurrentUpserts() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let container = try makeContainer(at: url)
        let source = CurrencyLocalDataSource(modelContainer: container)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for value in 1...20 {
                group.addTask {
                    try await source.saveRate(from: "USD", to: "EUR", rate: Double(value))
                }
            }
            try await group.waitForAll()
        }
        let reopened = try makeContainer(at: url)
        let reader = CurrencyLocalDataSource(modelContainer: reopened)
        let rate = try await reader.loadCachedRate(from: "USD", to: "EUR")
        XCTAssertNotNil(rate)
        let context = ModelContext(reopened)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExchangeRate>()), 1)
    }

    func testPersistentHistoryTrimDeleteAndClearSurviveReopen() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let container = try makeContainer(at: url)
        let writer = try ConversionHistoryActor(modelContainer: container, maxEntries: 2)
        for value in 1...3 {
            try await writer.saveConversion(from: "USD", to: "EUR", amount: Double(value), result: Double(value), rate: 1)
        }
        let reader = try ConversionHistoryActor(modelContainer: makeContainer(at: url))
        var entries = try await reader.fetchHistory()
        XCTAssertEqual(entries.count, 2)
        let id = try XCTUnwrap(entries.first?.id)
        try await reader.deleteConversion(id: id)
        entries = try await reader.fetchHistory()
        XCTAssertEqual(entries.count, 1)
        try await reader.clearAllHistory()
        let finalReader = try ConversionHistoryActor(modelContainer: makeContainer(at: url))
        let finalEntries = try await finalReader.fetchHistory()
        XCTAssertTrue(finalEntries.isEmpty)
    }

    func testReadOnlyRateSaveRollsBackPendingUpdateAndInsert() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        try await seed(at: url)
        let source = CurrencyLocalDataSource(modelContainer: try makeContainer(at: url, writable: false))
        await expectFailure { try await source.saveRate(from: "USD", to: "EUR", rate: 7) }
        let original = try await source.loadCachedRate(from: "USD", to: "EUR")
        XCTAssertEqual(original?.rate, 0.9)
        await expectFailure { try await source.saveRate(from: "USD", to: "NOK", rate: 10) }
        let absent = try await source.loadCachedRate(from: "USD", to: "NOK")
        XCTAssertNil(absent)

        let recovered = CurrencyLocalDataSource(modelContainer: try makeContainer(at: url))
        try await recovered.saveRate(from: "USD", to: "EUR", rate: 0.95)
        let committed = try await recovered.loadCachedRate(from: "USD", to: "EUR")
        let stillAbsent = try await recovered.loadCachedRate(from: "USD", to: "NOK")
        XCTAssertEqual(committed?.rate, 0.95)
        XCTAssertNil(stillAbsent)
    }

    func testReadOnlyHistorySaveRollsBackInsertTrimDeleteAndClear() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        try await seed(at: url)
        let actor = try ConversionHistoryActor(
            modelContainer: makeContainer(at: url, writable: false), maxEntries: 2
        )
        let original = try await actor.fetchHistory()
        await expectFailure {
            try await actor.saveConversion(from: "USD", to: "NOK", amount: 99, result: 999, rate: 10)
        }
        let afterInsert = try await actor.fetchHistory()
        XCTAssertEqual(Set(afterInsert.map(\.id)), Set(original.map(\.id)))
        let id = try XCTUnwrap(original.first?.id)
        await expectFailure { try await actor.deleteConversion(id: id) }
        await expectFailure { try await actor.clearAllHistory() }
        let afterFailures = try await actor.fetchHistory()
        XCTAssertEqual(Set(afterFailures.map(\.id)), Set(original.map(\.id)))

        let recovered = try ConversionHistoryActor(modelContainer: makeContainer(at: url))
        try await recovered.saveConversion(from: "USD", to: "SGD", amount: 5, result: 6, rate: 1.2)
        let committed = try await recovered.fetchHistory()
        XCTAssertEqual(committed.count, 3)
        XCTAssertFalse(committed.contains { $0.amount == 99 })
    }
}
