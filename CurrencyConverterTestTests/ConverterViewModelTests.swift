//
//  ConverterViewModelTests.swift
//  CurrencyConverterTestTests
//
//  Created by Yauheni Kozich on 21.05.25.
//

import XCTest
@testable import CurrencyConverterTest

@MainActor
final class ConverterViewModelTests: XCTestCase {
    var viewModel: ConverterViewModel!
    var mockRepository: MockCurrencyRepository!
    var mockFormatter: MockNumberFormatter!
    var conversionUseCase: CurrencyConversionUseCase!
    var loadCurrenciesUseCase: LoadCurrenciesUseCase!
    var saveConversionHistoryUseCase: SaveConversionHistoryUseCase!

    override func setUp() async throws {
        mockRepository = MockCurrencyRepository()
        mockFormatter = MockNumberFormatter()

        conversionUseCase = CurrencyConversionUseCase(repository: mockRepository)
        loadCurrenciesUseCase = LoadCurrenciesUseCase(repository: mockRepository)
        saveConversionHistoryUseCase = SaveConversionHistoryUseCase(historyActor: MockConversionHistoryActor())

        // Set up UserDefaults with default values
        UserDefaults.standard.set("USD", forKey: "fromCurrency")
        UserDefaults.standard.set("EUR", forKey: "toCurrency")

        viewModel = ConverterViewModel(
            conversionUseCase: conversionUseCase,
            loadCurrenciesUseCase: loadCurrenciesUseCase,
            saveConversionHistoryUseCase: saveConversionHistoryUseCase,
            numberFormatter: mockFormatter
        )
    }

    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        mockFormatter = nil
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "fromCurrency")
        UserDefaults.standard.removeObject(forKey: "toCurrency")
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.fromCurrency, "USD")
        XCTAssertEqual(viewModel.toCurrency, "EUR")
        XCTAssertEqual(viewModel.amount, "")
        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.currencies, [])
        XCTAssertFalse(viewModel.isLoadingCurrencies)
        XCTAssertNil(viewModel.currenciesLoadingError)
    }

    func testConvertSuccess() async throws {
        viewModel.setAmount("100")
        mockFormatter.parseResult = 100.0
        mockRepository.convertResult = ConversionResult(result: 85.0, rate: 0.85)
        mockFormatter.formatResults = ["85.0": "85.00", "0.85": "0.8500"]

        viewModel.convert()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.result, "85.00")
        XCTAssertEqual(viewModel.rate, "0.8500")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testConvertInvalidAmount() async throws {
        viewModel.setAmount("invalid")
        mockFormatter.parseResult = nil

        viewModel.convert()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertEqual(viewModel.errorMessage, "Неверный формат суммы")
    }

    func testConvertNegativeAmount() async throws {
        viewModel.setAmount("-100")
        mockFormatter.parseResult = -100.0

        viewModel.convert()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertEqual(viewModel.errorMessage, "Некорректная сумма: -100.0")
    }

    func testConvertUseCaseError() async throws {
        viewModel.setAmount("100")
        mockFormatter.parseResult = 100.0
        mockRepository.convertError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])

        viewModel.convert()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertEqual(viewModel.errorMessage, "Network error")
    }

    func testLoadCurrenciesSuccess() async throws {
        let expectedCurrencies: [String: Currency] = [
            "EUR": Currency(code: "EUR", name: "Euro"),
            "USD": Currency(code: "USD", name: "US Dollar")
        ]
        mockRepository.fetchCurrenciesResult = expectedCurrencies

        viewModel.loadCurrencies()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.currencies, ["EUR", "USD"])
        XCTAssertFalse(viewModel.isLoadingCurrencies)
        XCTAssertNil(viewModel.currenciesLoadingError)
    }

    func testLoadCurrenciesError() async throws {
        mockRepository.fetchCurrenciesError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Load error"])

        viewModel.loadCurrencies()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.currencies, [])
        XCTAssertFalse(viewModel.isLoadingCurrencies)
        XCTAssertEqual(viewModel.currenciesLoadingError, "Load error")
    }

    func testCurrencySelectionPersistence() {
        XCTAssertEqual(UserDefaults.standard.string(forKey: "fromCurrency"), "USD")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "toCurrency"), "EUR")

        viewModel.fromCurrency = "GBP"
        viewModel.toCurrency = "JPY"

        XCTAssertEqual(UserDefaults.standard.string(forKey: "fromCurrency"), "GBP")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "toCurrency"), "JPY")
    }

    func testInitializationWithSavedPreferences() async throws {
        // Save custom values
        UserDefaults.standard.set("GBP", forKey: "fromCurrency")
        UserDefaults.standard.set("JPY", forKey: "toCurrency")

        let mockRepo = MockCurrencyRepository()
        let customViewModel = ConverterViewModel(
            conversionUseCase: CurrencyConversionUseCase(repository: mockRepo),
            loadCurrenciesUseCase: LoadCurrenciesUseCase(repository: mockRepo),
            saveConversionHistoryUseCase: SaveConversionHistoryUseCase(historyActor: MockConversionHistoryActor()),
            numberFormatter: mockFormatter
        )

        XCTAssertEqual(customViewModel.fromCurrency, "GBP")
        XCTAssertEqual(customViewModel.toCurrency, "JPY")
    }
}

// MARK: - Mock Helpers

final class MockConversionHistoryActor: ConversionHistoryActorProtocol {
    private var saveConversionCalled = false
    private var savedConversions: [(from: String, to: String, amount: Double, result: Double, rate: Double)] = []

    func saveConversion(from: String, to: String, amount: Double, result: Double, rate: Double) async throws {
        saveConversionCalled = true
        savedConversions.append((from, to, amount, result, rate))
    }

    func deleteConversion(id: UUID) async throws {
        // Mock implementation - do nothing
    }

    func wasSaveConversionCalled() async -> Bool {
        saveConversionCalled
    }
}

// MARK: - Mock Repository

class MockCurrencyRepository: CurrencyRepository {
    var convertResult: ConversionResult?
    var convertError: Error?
    var fetchCurrenciesResult: [String: Currency]?
    var fetchCurrenciesError: Error?

    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        if let error = convertError {
            throw error
        }
        return convertResult ?? ConversionResult(result: 0, rate: 0)
    }

    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        if let error = fetchCurrenciesError {
            throw error
        }
        return fetchCurrenciesResult ?? [:]
    }
}

// MARK: - Mock Number Formatter

final class MockNumberFormatter: NumberFormatting {
    var parseResult: Double?
    var formatResults: [String: String] = [:]

    func format(_ value: Double, decimals: Int) -> String {
        return formatResults["\(value)"] ?? "\(value)"
    }

    func parse(_ string: String) -> Double? {
        return parseResult
    }
}
