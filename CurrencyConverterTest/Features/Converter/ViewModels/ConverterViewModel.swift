//
//  ConverterViewModel.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI

@MainActor
final class ConverterViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var fromCurrency = "USD" {
        didSet {
            guard fromCurrency != oldValue else { return }
            UserDefaults.standard.set(fromCurrency, forKey: "fromCurrency")
        }
    }

    @Published var toCurrency = "RUB" {
        didSet {
            guard toCurrency != oldValue else { return }
            UserDefaults.standard.set(toCurrency, forKey: "toCurrency")
        }
    }

    @Published private(set) var amount: String = ""
    @Published var result = ""
    @Published var rate = ""
    @Published var errorMessage: String?
    @Published var isConverting = false

    @Published var currencies: [String] = []
    @Published var isLoadingCurrencies = false
    @Published var currenciesLoadingError: String?

    // MARK: - Dependencies

    private let conversionUseCase: CurrencyConversionUseCase
    private let loadCurrenciesUseCase: LoadCurrenciesUseCase
    private let saveConversionHistoryUseCase: SaveConversionHistoryUseCase
    private let numberFormatter: NumberFormatting

    // MARK: - Private Properties

    private var convertTask: Task<Void, Never>?
    private var loadCurrenciesTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        conversionUseCase: CurrencyConversionUseCase,
        loadCurrenciesUseCase: LoadCurrenciesUseCase,
        saveConversionHistoryUseCase: SaveConversionHistoryUseCase,
        numberFormatter: NumberFormatting
    ) {
        self.conversionUseCase = conversionUseCase
        self.loadCurrenciesUseCase = loadCurrenciesUseCase
        self.saveConversionHistoryUseCase = saveConversionHistoryUseCase
        self.numberFormatter = numberFormatter

        // Восстанавливаем сохраненные значения
        if let savedFromCurrency = UserDefaults.standard.string(forKey: "fromCurrency") {
            fromCurrency = savedFromCurrency
        }

        if let savedToCurrency = UserDefaults.standard.string(forKey: "toCurrency") {
            toCurrency = savedToCurrency
        }
    }

    // MARK: - Public Methods

    func setAmount(_ newAmount: String) {
        amount = normalizeAmount(newAmount)
    }

    func convert() {
        convertTask?.cancel()
        convertTask = Task { [weak self] in
            await self?.performConversion()
        }
    }

    func loadCurrencies() {
        loadCurrenciesTask?.cancel()
        loadCurrenciesTask = Task { [weak self] in
            await self?.loadSupportedCurrencies(forceRefresh: false)
        }
    }

    func refreshCurrencies() {
        loadCurrenciesTask?.cancel()
        loadCurrenciesTask = Task { [weak self] in
            await self?.loadSupportedCurrencies(forceRefresh: true)
        }
    }

    // MARK: - Private Methods

    private func performConversion() async {
        isConverting = true
        defer { isConverting = false }

        guard !Task.isCancelled else { return }

        guard let amountValue = numberFormatter.parse(amount) else {
            errorMessage = "Неверный формат суммы"
            return
        }

        errorMessage = nil
        result = ""
        rate = ""

        do {
            let conversion = try await conversionUseCase.execute(
                from: fromCurrency,
                to: toCurrency,
                amount: amountValue
            )

            guard !Task.isCancelled else { return }

            result = numberFormatter.format(
                conversion.result,
                decimals: 2
            )

            rate = numberFormatter.format(
                conversion.rate,
                decimals: 4
            )

            // Сохраняем в историю через UseCase
            do {
                try await saveConversionHistoryUseCase.execute(
                    from: fromCurrency,
                    to: toCurrency,
                    amount: amountValue,
                    result: conversion.result,
                    rate: conversion.rate
                )
            } catch {
                Logger.log("Не удалось сохранить историю конвертации: \(error)", level: .warning)
            }

        } catch let appError as AppError {
            guard !Task.isCancelled else { return }
            
            // Показываем user-friendly сообщение
            errorMessage = appError.errorDescription
            
            // Логируем технические детали
            if let reason = appError.failureReason {
                Logger.log("Conversion error: \(reason)", level: .error)
            }
            
            result = ""
            rate = ""
        } catch {
            guard !Task.isCancelled else { return }
            
            // Fallback для неизвестных ошибок
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

            // Показываем user-friendly сообщение
            currenciesLoadingError = appError.errorDescription

            // Логируем технические детали
            if let reason = appError.failureReason {
                Logger.log("Load currencies error: \(reason)", level: .error)
            }
        } catch {
            guard !Task.isCancelled else { return }

            // Fallback для неизвестных ошибок
            currenciesLoadingError = "Не удалось загрузить валюты"
            Logger.log("Unknown load currencies error: \(error)", level: .error)
        }
    }

    // MARK: - Input Normalization

    private func normalizeAmount(_ input: String) -> String {
        var filtered = input
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.".contains($0) }
        let components = filtered.split(separator: ".")
        if components.count > 2 {
            filtered = components.prefix(2).joined(separator: ".")
        }
        return filtered
    }
}
