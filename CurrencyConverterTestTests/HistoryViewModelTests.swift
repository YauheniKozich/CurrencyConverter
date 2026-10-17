//
//  HistoryViewModelTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 17.10.26.
//

import XCTest
@testable import CurrencyConverterTest

private final class MockHistoryStore: ConversionHistoryStore, ConversionHistoryReader, @unchecked Sendable {
    var storedEntries: [ConversionHistoryEntry] = []

    func saveConversion(from: String, to: String, amount: Double, result: Double, rate: Double) async throws {
        let entry = ConversionHistoryEntry(
            id: UUID(),
            from: from,
            to: to,
            amount: amount,
            result: result,
            rate: rate,
            date: Date()
        )
        storedEntries.insert(entry, at: 0)
    }

    func fetchHistory() async throws -> [ConversionHistoryEntry] {
        return storedEntries
    }

    func deleteConversion(id: UUID) async throws {
        storedEntries.removeAll { $0.id == id }
    }

    func clearHistory() async throws {
        storedEntries.removeAll()
    }
}

@MainActor
final class HistoryViewModelTests: XCTestCase {

    private var mockStore: MockHistoryStore!
    private var useCase: ConversionHistoryUseCase!
    private var viewModel: HistoryViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockStore = MockHistoryStore()
        useCase = ConversionHistoryUseCase(historyActor: mockStore)
        viewModel = HistoryViewModel(historyUseCase: useCase)
    }

    override func tearDown() async throws {
        viewModel = nil
        useCase = nil
        mockStore = nil
        try await super.tearDown()
    }

    func testLoadHistory_populatesConversions() async {
        let entry = ConversionHistoryEntry(
            from: "USD",
            to: "EUR",
            amount: 100,
            result: 92.5,
            rate: 0.925
        )
        mockStore.storedEntries = [entry]

        await viewModel.loadHistory()

        XCTAssertEqual(viewModel.conversions.count, 1)
        XCTAssertEqual(viewModel.conversions.first?.from, "USD")
        XCTAssertEqual(viewModel.conversions.first?.to, "EUR")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDeleteConversion_removesEntry() async {
        let id = UUID()
        let entry = ConversionHistoryEntry(
            id: id,
            from: "USD",
            to: "EUR",
            amount: 50,
            result: 46.25,
            rate: 0.925
        )
        mockStore.storedEntries = [entry]
        await viewModel.loadHistory()
        XCTAssertEqual(viewModel.conversions.count, 1)

        await viewModel.deleteConversion(id: id)

        XCTAssertEqual(viewModel.conversions.count, 0)
    }

    func testCSVExportString_formatsHeadersAndRows() async {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let entry = ConversionHistoryEntry(
            from: "USD",
            to: "EUR",
            amount: 100,
            result: 92.5,
            rate: 0.925,
            date: fixedDate
        )
        mockStore.storedEntries = [entry]
        await viewModel.loadHistory()

        let csv = viewModel.csvExportString
        XCTAssertTrue(csv.hasPrefix("Date,From,To,Amount,Result,Rate\n"))
        XCTAssertTrue(csv.contains("USD,EUR,100.0,92.5,0.925"))
    }
}
