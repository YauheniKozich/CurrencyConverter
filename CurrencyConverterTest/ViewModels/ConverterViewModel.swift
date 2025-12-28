//
//  ConverterViewModel.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI
import SwiftData

@MainActor
final class ConverterViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var fromCurrency = "USD" {
        didSet {
            if isInitialized {
                userDefaults.set(fromCurrency, forKey: "fromCurrency")
            }
        }
    }

    @Published var toCurrency = "RUB" {
        didSet {
            if isInitialized {
                userDefaults.set(toCurrency, forKey: "toCurrency")
            }
        }
    }

    @Published var amount = ""
    @Published var result = ""
    @Published var rate = ""
    @Published var errorMessage: String?

    @Published var currencies: [String] = []
    @Published var isLoadingCurrencies = false
    @Published var currenciesLoadingError: String?

    // MARK: - Dependencies
    private let repository: CurrencyRepository
    private let numberFormatter: NumberFormatting
    private let userDefaults: UserDefaultsProtocol

    // MARK: - Private Properties
    private var convertTask: Task<Void, Never>? = nil
    private var loadCurrenciesTask: Task<Void, Never>? = nil
    private var isInitialized = false

    init(repository: CurrencyRepository,
         numberFormatter: NumberFormatting,
         userDefaults: UserDefaultsProtocol = UserDefaults.standard) {
        self.repository = repository
        self.numberFormatter = numberFormatter
        self.userDefaults = userDefaults

        // Load saved currencies from UserDefaults
        self.fromCurrency = userDefaults.string(forKey: "fromCurrency") ?? "USD"
        self.toCurrency = userDefaults.string(forKey: "toCurrency") ?? "RUB"

        // Mark as initialized after setting initial values
        self.isInitialized = true
    }

    func convert() {
        convertTask?.cancel()
        convertTask = Task { @MainActor in
            await self.performConversion()
        }
    }
    
    func loadCurrencies() {
        loadCurrenciesTask?.cancel()
        loadCurrenciesTask = Task { @MainActor in
            await self.performLoadCurrencies()
        }
    }
    
    private func performConversion() async {
        guard let amountValue = numberFormatter.parseDecimal(amount) else {
            errorMessage = "Неверный формат суммы"
            return
        }

        guard amountValue >= 0 else {
            errorMessage = "Сумма должна быть положительной"
            return
        }

        do {
            let conversion = try await repository.convert(from: fromCurrency, to: toCurrency, amount: amountValue)

            result = numberFormatter.formatDecimal(conversion.result, maximumFractionDigits: 2)
            rate = numberFormatter.formatDecimal(conversion.rate, maximumFractionDigits: 4)

            let historyItem = Conversion(from: fromCurrency, to: toCurrency, amount: amountValue, result: conversion.result, rate: conversion.rate)
            await repository.saveConversion(historyItem)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            result = ""
            rate = ""
        }
    }
    
    private func performLoadCurrencies() async {
        guard currencies.isEmpty else { return }
        isLoadingCurrencies = true
        do {
            let map = try await repository.fetchSupportedCurrencies()
            let sorted = map.values.map { $0.code }.sorted()
            currencies = sorted
            isLoadingCurrencies = false
            currenciesLoadingError = nil
        } catch {
            Logger.log("Ошибка загрузки валют: \(error)")
            currenciesLoadingError = error.localizedDescription
            isLoadingCurrencies = false
        }
    }
}
