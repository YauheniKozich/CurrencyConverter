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
    var mockUserDefaults: MockUserDefaults!

    override func setUp() async throws {
        mockRepository = MockCurrencyRepository()
        mockFormatter = MockNumberFormatter()
        mockUserDefaults = MockUserDefaults()

        // Set up mock UserDefaults with default values
        mockUserDefaults.set("USD", forKey: "fromCurrency")
        mockUserDefaults.set("EUR", forKey: "toCurrency")

        viewModel = ConverterViewModel(
            repository: mockRepository,
            numberFormatter: mockFormatter,
            userDefaults: mockUserDefaults
        )
    }

    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        mockFormatter = nil
        mockUserDefaults = nil
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

    func testMainActorIsolation() async {
        // Test that we can access Main Actor isolated properties
        await MainActor.run {
            XCTAssertEqual(viewModel.fromCurrency, "USD")
            viewModel.fromCurrency = "GBP"
            XCTAssertEqual(viewModel.fromCurrency, "GBP")
        }
    }

    func testConvertSuccess() async throws {
        // Given
        viewModel.amount = "100"
        mockFormatter.parseResult = 100.0
        mockRepository.convertResult = ConversionResult(result: 85.0, rate: 0.85)
        mockFormatter.formatResults = ["85": "85.00", "0.85": "0.8500"]

        // When
        viewModel.convert()

        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then
        XCTAssertEqual(viewModel.result, "85.00")
        XCTAssertEqual(viewModel.rate, "0.8500")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(mockRepository.saveConversionCalled)
    }

    func testConvertInvalidAmount() async throws {
        // Given
        viewModel.amount = "invalid"
        mockFormatter.parseResult = nil

        // When
        viewModel.convert()

        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertEqual(viewModel.errorMessage, "Неверный формат суммы")
    }

    func testConvertNegativeAmount() async throws {
        // Given
        viewModel.amount = "-100"
        mockFormatter.parseResult = -100.0

        // When
        viewModel.convert()

        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertEqual(viewModel.errorMessage, "Сумма должна быть положительной")
    }

    func testConvertRepositoryError() async throws {
        // Given
        viewModel.amount = "100"
        mockFormatter.parseResult = 100.0
        mockRepository.convertError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])

        // When
        viewModel.convert()

        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.result, "")
        XCTAssertEqual(viewModel.rate, "")
        XCTAssertEqual(viewModel.errorMessage, "Network error")
    }

    func testLoadCurrenciesSuccess() async throws {
        // Given
        let expectedCurrencies = ["USD": Currency(name: "US Dollar", code: "USD"),
                                 "EUR": Currency(name: "Euro", code: "EUR")]
        mockRepository.fetchCurrenciesResult = expectedCurrencies

        // When
        viewModel.loadCurrencies()

        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.currencies, ["EUR", "USD"]) // Sorted alphabetically
        XCTAssertFalse(viewModel.isLoadingCurrencies)
        XCTAssertNil(viewModel.currenciesLoadingError)
    }

    func testLoadCurrenciesError() async throws {
        // Given
        mockRepository.fetchCurrenciesError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Load error"])

        // When
        viewModel.loadCurrencies()

        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.currencies, [])
        XCTAssertFalse(viewModel.isLoadingCurrencies)
        XCTAssertEqual(viewModel.currenciesLoadingError, "Load error")
    }

    func testCurrencySelectionPersistence() {
        // Given
        XCTAssertEqual(mockUserDefaults.testStorage["fromCurrency"] as? String, "USD")
        XCTAssertEqual(mockUserDefaults.testStorage["toCurrency"] as? String, "EUR")

        // When
        viewModel.fromCurrency = "GBP"
        viewModel.toCurrency = "JPY"

        // Then
        XCTAssertEqual(mockUserDefaults.testStorage["fromCurrency"] as? String, "GBP")
        XCTAssertEqual(mockUserDefaults.testStorage["toCurrency"] as? String, "JPY")
    }

    func testInitializationWithSavedPreferences() async throws {
        // Given
        let customUserDefaults = MockUserDefaults()
        customUserDefaults.set("GBP", forKey: "fromCurrency")
        customUserDefaults.set("JPY", forKey: "toCurrency")

        // When
        let customViewModel = ConverterViewModel(
            repository: mockRepository,
            numberFormatter: mockFormatter,
            userDefaults: customUserDefaults
        )

        // Then
        XCTAssertEqual(customViewModel.fromCurrency, "GBP")
        XCTAssertEqual(customViewModel.toCurrency, "JPY")
    }
}

// MARK: - Mock Implementations

class MockCurrencyRepository: CurrencyRepository {
    var convertResult: ConversionResult?
    var convertError: Error?
    var fetchCurrenciesResult: [String: Currency]?
    var fetchCurrenciesError: Error?
    var saveConversionCalled = false

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

    func saveConversion(_ conversion: Conversion) async {
        saveConversionCalled = true
    }
}

class MockNumberFormatter: NumberFormatting {
    var parseResult: Double?
    var formatResults: [String: String] = [:]

    func formatDecimal(_ value: Double, maximumFractionDigits: Int) -> String {
        return formatResults["\(value)"] ?? "\(value)"
    }

    func parseDecimal(_ string: String) -> Double? {
        return parseResult
    }
}
