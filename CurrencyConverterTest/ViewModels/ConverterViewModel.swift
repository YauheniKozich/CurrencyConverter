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
    @AppStorage("fromCurrency") var fromCurrency = "USD"
    @AppStorage("toCurrency") var toCurrency = "RUB"
    @Published var amount = ""
    @Published var result = ""
    @Published var rate = ""
    @Published var errorMessage: String?
    
    @Published var currencies: [String] = []
    @Published var isLoadingCurrencies = false
    @Published var currenciesLoadingError: String?
    
    var context: ModelContext?
    let repository: CurrencyRepository
    
    private var convertTask: Task<Void, Never>? = nil
    private var loadCurrenciesTask: Task<Void, Never>? = nil
    
    init(context: ModelContext? = nil, repository: CurrencyRepository) {
        self.context = context
        self.repository = repository
    }
    
    func convert() {
        convertTask?.cancel()
        convertTask = Task {
            await performConversion()
        }
    }
    
    func loadCurrencies() {
        loadCurrenciesTask?.cancel()
        loadCurrenciesTask = Task {
            await performLoadCurrencies()
        }
    }
    
    private func performConversion() async {
        guard let context else { return }
        guard let amountValue = Double(amount) else {
            errorMessage = "Неверный формат суммы"
            return
        }
        do {
            let conversion = try await repository.convert(from: fromCurrency, to: toCurrency, amount: amountValue)
            
            let resultFormatter = makeFormatter(maxFractionDigits: 2)
            result = resultFormatter.string(from: NSNumber(value: conversion.result)) ?? "\(conversion.result)"
            
            let rateFormatter = makeFormatter(maxFractionDigits: 4)
            rate = rateFormatter.string(from: NSNumber(value: conversion.rate)) ?? "\(conversion.rate)"
            
            let historyItem = Conversion(from: fromCurrency, to: toCurrency, amount: amountValue, result: conversion.result, rate: conversion.rate)
            context.insert(historyItem)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            result = ""
            rate = ""
        }
    }
    
    private func performLoadCurrencies() async {
        guard context != nil else { return }
        guard currencies.isEmpty else { return }
        isLoadingCurrencies = true
        do {
            let map = try await repository.fetchSupportedCurrencies()
            let sorted = map.values.map { $0.code }.sorted()
            self.currencies = sorted
            self.isLoadingCurrencies = false
            self.currenciesLoadingError = nil
        } catch {
            print("Ошибка загрузки валют: \(error)")
            self.currenciesLoadingError = error.localizedDescription
            self.isLoadingCurrencies = false
        }
    }
    
    private func makeFormatter(maxFractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.locale = Locale.current
        return formatter
    }
}
