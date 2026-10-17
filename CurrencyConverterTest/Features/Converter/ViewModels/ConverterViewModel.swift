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
    private(set) var inverseRate: String = ""
    private(set) var isOfflineRate: Bool = false
    private(set) var errorMessage: String?
    private(set) var isConverting: Bool = false

    private(set) var currencies: [String] = []
    private(set) var isLoadingCurrencies: Bool = false
    private(set) var currenciesLoadingError: String?
    private(set) var errorType: ErrorType = .unknown

    var showErrorAlert: Bool {
        guard errorMessage != nil else { return false }
        return errorType.isNonRecoverable
    }

    var hasValidationError: Bool {
        errorType == .validation
    }

    var isValidAmount: Bool {
        numberFormatter.parse(amount) != nil
    }

    var formattedResult: String {
        "\(amount) \(fromCurrency) = \(result) \(toCurrency)"
    }

    var directRateText: String {
        guard !rate.isEmpty else { return "" }
        return "1 \(fromCurrency) = \(rate) \(toCurrency)"
    }

    var inverseRateText: String {
        guard !inverseRate.isEmpty else { return "" }
        return "1 \(toCurrency) = \(inverseRate) \(fromCurrency)"
    }

    private let conversionService: ConversionService
    private let conversionFormatting: any ConversionFormatting
    private let loadCurrenciesUseCase: any LoadCurrenciesUseCaseProtocol
    private let numberFormatter: any NumberFormatting
    private let preferences: any UserPreferencesProtocol

    private var convertTask: Task<Void, Never>?
    private var conversionRequestID = 0
    private var currencyLoadRequestID = 0

    init(
        conversionUseCase: any CurrencyConversionUseCaseProtocol,
        loadCurrenciesUseCase: any LoadCurrenciesUseCaseProtocol,
        saveConversionHistoryUseCase: any SaveConversionHistoryUseCaseProtocol,
        numberFormatter: any NumberFormatting,
        preferences: any UserPreferencesProtocol = UserPreferences()
    ) {
        let preferences = preferences
        self.conversionService = ConversionService(
            conversionUseCase: conversionUseCase,
            saveConversionHistoryUseCase: saveConversionHistoryUseCase,
            numberFormatter: numberFormatter
        )
        self.conversionFormatting = ConversionPresentationFormatter(numberFormatter: numberFormatter)
        self.loadCurrenciesUseCase = loadCurrenciesUseCase
        self.numberFormatter = numberFormatter
        self.preferences = preferences
        self.fromCurrency = preferences.fromCurrency
        self.toCurrency = preferences.toCurrency
    }

    func setAmount(_ newAmount: String) {
        amount = normalizeAmount(newAmount)
        errorMessage = nil
        errorType = .unknown
    }

    func applyHistoryEntry(_ entry: ConversionHistoryEntry) {
        fromCurrency = entry.from
        toCurrency = entry.to
        let formattedAmount: String
        if entry.amount.truncatingRemainder(dividingBy: 1) == 0 {
            formattedAmount = String(Int(entry.amount))
        } else {
            formattedAmount = numberFormatter.format(entry.amount, decimals: 2)
        }
        setAmount(formattedAmount)
        convert()
    }

    func swapCurrencies() {
        let temp = fromCurrency
        fromCurrency = toCurrency
        toCurrency = temp
        if isValidAmount {
            convert()
        }
    }

    func clearError() {
        errorMessage = nil
        errorType = .unknown
    }

    func convert() {
        convertTask?.cancel()
        conversionRequestID &+= 1
        let requestID = conversionRequestID
        let from = fromCurrency
        let to = toCurrency
        let amount = amount
        isConverting = true
        convertTask = Task { [weak self] in
            await self?.performConversion(requestID: requestID, from: from, to: to, amount: amount)
        }
    }

    func loadCurrenciesAsync() async {
        guard !Task.isCancelled else { return }
        await loadSupportedCurrencies(forceRefresh: false)
    }

    func refreshCurrencies() async {
        guard !Task.isCancelled else { return }
        await loadSupportedCurrencies(forceRefresh: true)
    }

    private func performConversion(requestID: Int, from: String, to: String, amount: String) async {
        defer {
            if requestID == conversionRequestID {
                isConverting = false
                convertTask = nil
            }
        }

        guard !Task.isCancelled, requestID == conversionRequestID else { return }

        do {
            let conversion = try await conversionService.convert(
                from: from,
                to: to,
                amount: amount
            )

            guard !Task.isCancelled, requestID == conversionRequestID else { return }

            result = conversionFormatting.formatResult(conversion.result)
            rate = conversionFormatting.formatRate(conversion.rate)
            inverseRate = conversion.rate > 0 ? conversionFormatting.formatRate(1.0 / conversion.rate) : ""
            isOfflineRate = conversion.isStaleRate
            errorMessage = nil
            errorType = .unknown

        } catch let conversionError as ConversionService.ConversionError {
            guard !Task.isCancelled, requestID == conversionRequestID else { return }
            errorMessage = conversionError.errorDescription
            errorType = .validation
            result = ""
            rate = ""
            inverseRate = ""
            isOfflineRate = false

        } catch let appError as AppError {
            guard !Task.isCancelled, requestID == conversionRequestID else { return }
            errorMessage = appError.errorDescription
            errorType = ErrorType.from(appError)

            if let reason = appError.failureReason {
                Logger.log("Conversion error: \(reason)", level: .error)
            }

            result = ""
            rate = ""
            inverseRate = ""
            isOfflineRate = false

        } catch {
            guard !Task.isCancelled, requestID == conversionRequestID else { return }
            errorMessage = "Произошла ошибка. Попробуйте снова."
            errorType = .unknown
            Logger.log("Unknown conversion error: \(error)", level: .error)
            result = ""
            rate = ""
            inverseRate = ""
            isOfflineRate = false
        }
    }

    private func loadSupportedCurrencies(forceRefresh: Bool) async {
        guard !Task.isCancelled else { return }
        currencyLoadRequestID &+= 1
        let requestID = currencyLoadRequestID
        isLoadingCurrencies = true
        currenciesLoadingError = nil
        defer {
            if requestID == currencyLoadRequestID {
                isLoadingCurrencies = false
            }
        }

        do {
            let loadedCurrencies = try await loadCurrenciesUseCase.execute(forceRefresh: forceRefresh)
            guard !Task.isCancelled, requestID == currencyLoadRequestID else { return }
            currencies = loadedCurrencies
        } catch let appError as AppError {
            guard !Task.isCancelled, requestID == currencyLoadRequestID else { return }

            currenciesLoadingError = appError.errorDescription

            if let reason = appError.failureReason {
                Logger.log("Load currencies error: \(reason)", level: .error)
            }
        } catch {
            guard !Task.isCancelled, requestID == currencyLoadRequestID else { return }

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
