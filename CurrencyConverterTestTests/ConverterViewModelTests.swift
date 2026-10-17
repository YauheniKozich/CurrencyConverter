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
    var mockPreferences: MockUserPreferences!
    var conversionUseCase: CurrencyConversionUseCase!
    var loadCurrenciesUseCase: LoadCurrenciesUseCase!
    var saveConversionHistoryUseCase: SaveConversionHistoryUseCase!

    override func setUp() async throws {
        mockRepository = MockCurrencyRepository()
        mockFormatter = MockNumberFormatter()
        mockPreferences = MockUserPreferences(fromCurrency: "USD", toCurrency: "EUR")

        conversionUseCase = CurrencyConversionUseCase(repository: mockRepository)
        loadCurrenciesUseCase = LoadCurrenciesUseCase(repository: mockRepository)
        saveConversionHistoryUseCase = SaveConversionHistoryUseCase(historyActor: MockConversionHistoryActor())

        viewModel = ConverterViewModel(
            conversionUseCase: conversionUseCase,
            loadCurrenciesUseCase: loadCurrenciesUseCase,
            saveConversionHistoryUseCase: saveConversionHistoryUseCase,
            numberFormatter: mockFormatter,
            preferences: mockPreferences
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        mockRepository = nil
        mockFormatter = nil
        mockPreferences = nil
        try await super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.fromCurrency, "USD")
        XCTAssertEqual(viewModel.toCurrency, "EUR")
        XCTAssertEqual(viewModel.amount, "")
        XCTAssertFalse(viewModel.isValidAmount)
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
        XCTAssertFalse(viewModel.inverseRate.isEmpty)
        XCTAssertEqual(viewModel.directRateText, "1 USD = 0.8500 EUR")
        XCTAssertTrue(viewModel.inverseRateText.hasPrefix("1 EUR = "))
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isOfflineRate)
    }

    func testConvertDisplaysOfflineBadgeWhenStaleRateUsed() async throws {
        viewModel.setAmount("100")
        mockFormatter.parseResult = 100.0
        mockRepository.convertResult = ConversionResult(result: 85.0, rate: 0.85, isStaleRate: true)
        mockFormatter.formatResults = ["85.0": "85.00", "0.85": "0.8500"]

        viewModel.convert()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.result, "85.00")
        XCTAssertEqual(viewModel.rate, "0.8500")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isOfflineRate)
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

    func testIsValidAmountReflectsParsableAmount() {
        viewModel.setAmount("12.5")
        mockFormatter.parseResult = 12.5

        XCTAssertTrue(viewModel.isValidAmount)

        viewModel.setAmount(".")
        mockFormatter.parseResult = nil

        XCTAssertFalse(viewModel.isValidAmount)
    }

    func testConvertNegativeAmount() async throws {
        viewModel.setAmount("-100")
        mockFormatter.parseResult = -100.0

        viewModel.convert()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertEqual(viewModel.errorMessage, "Некорректная сумма")
    }

    func testConvertUseCaseError() async throws {
        viewModel.setAmount("100")
        mockFormatter.parseResult = 100.0
        mockRepository.convertError = AppError.networkUnavailable

        viewModel.convert()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertEqual(viewModel.errorMessage, "Нет подключения к интернету")
    }

    func testLoadCurrenciesSuccess() async throws {
        let expectedCurrencies: [String: Currency] = [
            "EUR": Currency(code: "EUR", name: "Euro"),
            "USD": Currency(code: "USD", name: "US Dollar")
        ]
        mockRepository.fetchCurrenciesResult = expectedCurrencies

        await viewModel.loadCurrenciesAsync()

        XCTAssertEqual(viewModel.currencies, ["EUR", "USD"])
        XCTAssertFalse(viewModel.isLoadingCurrencies)
        XCTAssertNil(viewModel.currenciesLoadingError)
    }

    func testLoadCurrenciesError() async throws {
        mockRepository.fetchCurrenciesError = AppError.networkUnavailable

        await viewModel.loadCurrenciesAsync()

        XCTAssertEqual(viewModel.currencies, [])
        XCTAssertFalse(viewModel.isLoadingCurrencies)
        XCTAssertEqual(viewModel.currenciesLoadingError, "Нет подключения к интернету")
    }

    func testCurrencySelectionPersistence() {
        XCTAssertEqual(mockPreferences.fromCurrency, "USD")
        XCTAssertEqual(mockPreferences.toCurrency, "EUR")

        viewModel.fromCurrency = "GBP"
        viewModel.toCurrency = "JPY"

        XCTAssertEqual(mockPreferences.fromCurrency, "GBP")
        XCTAssertEqual(mockPreferences.toCurrency, "JPY")
    }

    func testInitializationWithSavedPreferences() async throws {
        let savedPreferences = MockUserPreferences(fromCurrency: "GBP", toCurrency: "JPY")

        let mockRepo = MockCurrencyRepository()
        let customViewModel = ConverterViewModel(
            conversionUseCase: CurrencyConversionUseCase(repository: mockRepo),
            loadCurrenciesUseCase: LoadCurrenciesUseCase(repository: mockRepo),
            saveConversionHistoryUseCase: SaveConversionHistoryUseCase(historyActor: MockConversionHistoryActor()),
            numberFormatter: mockFormatter,
            preferences: savedPreferences
        )

        XCTAssertEqual(customViewModel.fromCurrency, "GBP")
        XCTAssertEqual(customViewModel.toCurrency, "JPY")
    }

    func testSwapCurrencies() {
        viewModel.fromCurrency = "USD"
        viewModel.toCurrency = "EUR"

        viewModel.swapCurrencies()

        XCTAssertEqual(viewModel.fromCurrency, "EUR")
        XCTAssertEqual(viewModel.toCurrency, "USD")
        XCTAssertEqual(mockPreferences.fromCurrency, "EUR")
        XCTAssertEqual(mockPreferences.toCurrency, "USD")
    }

    func testSwapCurrenciesTriggersConversionWhenAmountIsValid() async throws {
        mockRepository.convertResult = ConversionResult(result: 110.0, rate: 1.1)
        mockFormatter.parseResult = 100.0
        mockFormatter.formatResults = ["110.0": "110.00", "1.1": "1.1000"]

        viewModel.fromCurrency = "USD"
        viewModel.toCurrency = "EUR"
        viewModel.setAmount("100")

        viewModel.swapCurrencies()

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.fromCurrency, "EUR")
        XCTAssertEqual(viewModel.toCurrency, "USD")
        XCTAssertEqual(viewModel.result, "110.00")
        XCTAssertEqual(viewModel.rate, "1.1000")
    }

    func testApplyHistoryEntry_withWholeAmount_appliesAndConverts() async throws {
        mockFormatter.parseResult = 250.0
        mockRepository.convertResult = ConversionResult(result: 48000.0, rate: 192.0)
        mockFormatter.formatResults = ["48000.0": "48000.00", "192.0": "192.0000"]

        let entry = ConversionHistoryEntry(
            id: UUID(),
            from: "GBP",
            to: "JPY",
            amount: 250.0,
            result: 48000.0,
            rate: 192.0,
            date: Date()
        )

        viewModel.applyHistoryEntry(entry)

        XCTAssertEqual(viewModel.fromCurrency, "GBP")
        XCTAssertEqual(viewModel.toCurrency, "JPY")
        XCTAssertEqual(viewModel.amount, "250")

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(viewModel.result, "48000.00")
    }

    func testApplyHistoryEntry_withDecimalAmount_appliesAndConverts() async throws {
        mockFormatter.formatResults = ["99.95": "99.95", "91.95": "91.95", "0.92": "0.9200"]
        mockFormatter.parseResult = 99.95
        mockRepository.convertResult = ConversionResult(result: 91.95, rate: 0.92)

        let entry = ConversionHistoryEntry(
            id: UUID(),
            from: "USD",
            to: "EUR",
            amount: 99.95,
            result: 91.95,
            rate: 0.92,
            date: Date()
        )

        viewModel.applyHistoryEntry(entry)

        XCTAssertEqual(viewModel.fromCurrency, "USD")
        XCTAssertEqual(viewModel.toCurrency, "EUR")
        XCTAssertEqual(viewModel.amount, "99.95")

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(viewModel.result, "91.95")
    }
}

// MARK: - Mock Preferences

@MainActor
final class MockUserPreferences: UserPreferencesProtocol {
    var fromCurrency: String
    var toCurrency: String
    var favoriteCurrencies: [String] = ["USD", "EUR", "RUB"]

    init(fromCurrency: String = "USD", toCurrency: String = "EUR") {
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
    }

    func isFavorite(currency: String) -> Bool {
        favoriteCurrencies.contains(currency)
    }

    func toggleFavorite(currency: String) {
        if favoriteCurrencies.contains(currency) {
            favoriteCurrencies.removeAll { $0 == currency }
        } else {
            favoriteCurrencies.append(currency)
        }
    }

    func restoreDefaults() {
        fromCurrency = "USD"
        toCurrency = "RUB"
        favoriteCurrencies = ["USD", "EUR", "RUB"]
    }
}

// MARK: - Mock Helpers

@MainActor
final class MockConversionHistoryActor: ConversionHistoryActorType {
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

@MainActor
class MockCurrencyRepository: CurrencyRepository, @unchecked Sendable {
    var convertResult: ConversionResult?
    var convertError: (any Error)?
    var fetchCurrenciesResult: [String: Currency]?
    var fetchCurrenciesError: (any Error)?

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

    func refreshSupportedCurrencies() async throws -> [String: Currency] {
        return try await fetchSupportedCurrencies()
    }
}

// MARK: - Mock Number Formatter

final class MockNumberFormatter: NumberFormatting, @unchecked Sendable {
    var parseResult: Double?
    var formatResults: [String: String] = [:]

    func format(_ value: Double, decimals: Int) -> String {
        return formatResults["\(value)"] ?? "\(value)"
    }

    func parse(_ string: String) -> Double? {
        return parseResult
    }
}
