//
//  LocalCurrencyDataSource.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

/// Протокол для локального источника данных валют
protocol LocalCurrencyDataSource: Sendable {
    func loadCachedRate(from: String, to: String) throws -> CachedRate?
    func saveRate(from: String, to: String, rate: Double) throws
    func loadCachedCurrencies() throws -> [String: Currency]?
    func saveCachedCurrencies(_ currencies: [String: Currency]) throws
    func clearCachedCurrencies() throws
}

// MARK: - Default Implementation

extension LocalCurrencyDataSource {
    func loadCachedCurrencies() throws -> [String: Currency]? { nil }
    func saveCachedCurrencies(_ currencies: [String: Currency]) throws {}
    func clearCachedCurrencies() throws {}
}

extension CurrencyLocalDataSource: LocalCurrencyDataSource {
}
