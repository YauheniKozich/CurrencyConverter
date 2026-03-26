//
//  ConverterViewModel.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI

@Observable
@MainActor
final class ConverterViewModel {

    private enum AmountNormalization {
        static let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        static let decimalSeparator = "."
        static let maxDecimalSeparators = 1
    }

    var fromCurrency: String {
        didSet {
            guard fromCurrency != oldValue else { return }
            preferences.fromCurrency = fromCurrency
        }
    }

    var toCurrency: String {
        didSet {
            guard toCurrency != oldValue else { return }
            preferences.toCurrency = toCurrency
        }
    }

    private(set) var amount: String = ""
    private(set) var result: String = ""
    private(set) var rate: String = ""
    private(set) var errorMessage: String?
    private(set) var isConverting: Bool = false

    private(set) var currencies: [String] = []
    private(set) var isLoadingCurrencies: Bool = false
    private(set) var currenciesLoadingError: String?

    var showErrorAlert: Bool {
        guard let error = errorMessage else { return false }
        return ErrorType.from(error).isNonRecoverable
    }

    var hasValidationError: Bool {
        errorMessage == "Неверный формат суммы"
    }

    var formattedResult: String {
        "\(amount) \(fromCurrency) = \(result) \(toCurrency)"
    }

    private let conversionService: ConversionService
    private let conversionFormatting: any ConversionFormatting
    private let loadCurrenciesUseCase: any LoadCurrenciesUseCaseProtocol
    private let preferences: UserPreferences

    private var convertTask: Task<Void, Never>?
    private var loadCurrenciesTask: Task<Void, Never>?

    init(
        conversionUseCase: any CurrencyConversionUseCaseProtocol,
        loadCurrenciesUseCase: any LoadCurrenciesUseCaseProtocol,
        saveConversionHistoryUseCase: any SaveConversionHistoryUseCaseProtocol,
        numberFormatter: any NumberFormatting,
        preferences: UserPreferences = UserPreferences()
    ) {
        let preferences = preferences
        self.conversionService = ConversionService(
            conversionUseCase: conversionUseCase,
            saveConversionHistoryUseCase: saveConversionHistoryUseCase,
            numberFormatter: numberFormatter
        )
        self.conversionFormatting = ConversionPresentationFormatter(numberFormatter: numberFormatter)
        self.loadCurrenciesUseCase = loadCurrenciesUseCase
        self.preferences = preferences
        self.fromCurrency = preferences.fromCurrency
        self.toCurrency = preferences.toCurrency
    }

    func setAmount(_ newAmount: String) {
        amount = normalizeAmount(newAmount)
        errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func convert() {
        convertTask?.cancel()
        convertTask = Task { [weak self] in
            guard let self = self else { return }
            await self.performConversion()
        }
    }

    func loadCurrencies() {
        loadCurrenciesTask?.cancel()
        loadCurrenciesTask = Task { [weak self] in
            guard let self = self else { return }
            await self.loadSupportedCurrencies(forceRefresh: false)
        }
    }

    func refreshCurrencies() async {
        loadCurrenciesTask?.cancel()
        loadCurrenciesTask = Task { [weak self] in
            guard let self = self else { return }
            await self.loadSupportedCurrencies(forceRefresh: true)
        }

        await loadCurrenciesTask?.value
    }

    private func performConversion() async {
        isConverting = true
        defer { isConverting = false }

        guard !Task.isCancelled else { return }

        do {
            let conversion = try await conversionService.convert(
                from: fromCurrency,
                to: toCurrency,
                amount: amount
            )

            guard !Task.isCancelled else { return }

            result = conversionFormatting.formatResult(conversion.result)
            rate = conversionFormatting.formatRate(conversion.rate)
            errorMessage = nil

        } catch let conversionError as ConversionService.ConversionError {
            guard !Task.isCancelled else { return }
            errorMessage = conversionError.errorDescription
            result = ""
            rate = ""

        } catch let appError as AppError {
            guard !Task.isCancelled else { return }
            errorMessage = appError.errorDescription

            if let reason = appError.failureReason {
                Logger.log("Conversion error: \(reason)", level: .error)
            }

            result = ""
            rate = ""

        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Произошла ошибка. Попробуйте снова."
            Logger.log("Unknown conversion error: \(error)", level: .error)
            result = ""
            rate = ""
        }
    }

    private func loadSupportedCurrencies(forceRefresh: Bool) async {
        isLoadingCurrencies = true
        currenciesLoadingError = nil
        defer { isLoadingCurrencies = false }

        do {
            let loadedCurrencies = try await loadCurrenciesUseCase.execute(forceRefresh: forceRefresh)
            guard !Task.isCancelled else { return }
            currencies = loadedCurrencies
        } catch let appError as AppError {
            guard !Task.isCancelled else { return }

            currenciesLoadingError = appError.errorDescription

            if let reason = appError.failureReason {
                Logger.log("Load currencies error: \(reason)", level: .error)
            }
        } catch {
            guard !Task.isCancelled else { return }

            currenciesLoadingError = "Не удалось загрузить валюты"
            Logger.log("Unknown load currencies error: \(error)", level: .error)
        }
    }

    private func normalizeAmount(_ input: String) -> String {
        let normalized = input
            .replacingOccurrences(of: ",", with: ".")
        var filtered = String(
            String.UnicodeScalarView(
                normalized.unicodeScalars.filter { Self.AmountNormalization.allowedCharacters.contains($0) }
            )
        )

        let components = filtered.split(separator: Character(Self.AmountNormalization.decimalSeparator))
        if components.count > Self.AmountNormalization.maxDecimalSeparators + 1 {
            filtered = components.prefix(Self.AmountNormalization.maxDecimalSeparators + 1).joined(
                separator: Self.AmountNormalization.decimalSeparator
            )
        }
        return filtered
    }
}
