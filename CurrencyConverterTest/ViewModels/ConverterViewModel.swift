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
            guard isInitialized else { return }
            userDefaults.set(fromCurrency, forKey: "fromCurrency")
        }
    }
    
    @Published var toCurrency = "RUB" {
        didSet {
            guard isInitialized else { return }
            userDefaults.set(toCurrency, forKey: "toCurrency")
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
    
    private var convertTask: Task<Void, Never>?
    private var loadCurrenciesTask: Task<Void, Never>?
    private var isInitialized = false
    
    // MARK: - Initialization
    
    init(
        repository: CurrencyRepository,
        numberFormatter: NumberFormatting,
        userDefaults: UserDefaultsProtocol = UserDefaults.standard
    ) {
        self.repository = repository
        self.numberFormatter = numberFormatter
        self.userDefaults = userDefaults
        
        // Восстанавливаем сохраненные значения
        if let savedFromCurrency = userDefaults.string(forKey: "fromCurrency") {
            fromCurrency = savedFromCurrency
        }
        
        if let savedToCurrency = userDefaults.string(forKey: "toCurrency") {
            toCurrency = savedToCurrency
        }
        
        isInitialized = true
    }
    
    // MARK: - Public Methods
    
    func convert() {
        convertTask?.cancel()
        convertTask = Task { @MainActor in
            await performConversion()
        }
    }
    
    func loadCurrencies() {
        guard currencies.isEmpty else { return }
        loadCurrenciesTask?.cancel()
        loadCurrenciesTask = Task { @MainActor in
            await loadSupportedCurrencies()
        }
    }
    
    // MARK: - Private Methods
    
    private func performConversion() async {
        guard let amountValue = numberFormatter.parse(amount) else {
            errorMessage = "Неверный формат суммы"
            return
        }
        
        guard amountValue >= 0 else {
            errorMessage = "Сумма должна быть положительной"
            return
        }
        
        errorMessage = nil
        result = ""
        rate = ""
        
        do {
            let conversion = try await repository.convert(
                from: fromCurrency,
                to: toCurrency,
                amount: amountValue
            )
            
            result = numberFormatter.format(
                conversion.result,
                decimals: 2
            )
            
            rate = numberFormatter.format(
                conversion.rate,
                decimals: 4
            )
            
            // Сохраняем в историю
            let historyItem = Conversion(
                from: fromCurrency,
                to: toCurrency,
                amount: amountValue,
                result: conversion.result,
                rate: conversion.rate
            )
            
            await repository.saveConversion(historyItem)
            
        } catch {
            errorMessage = error.localizedDescription
            result = ""
            rate = ""
        }
    }
    
    private func loadSupportedCurrencies() async {
        isLoadingCurrencies = true
        currenciesLoadingError = nil
        
        do {
            let currencyMap = try await repository.fetchSupportedCurrencies()
            
            // Сортируем коды валют по алфавиту
            let sortedCurrencies = currencyMap.values
                .map { $0.code }
                .sorted()
            
            currencies = sortedCurrencies
            
        } catch {
            currenciesLoadingError = error.localizedDescription
            Logger.log("Ошибка загрузки списка валют: \(error)")
        }
        
        isLoadingCurrencies = false
    }
}
