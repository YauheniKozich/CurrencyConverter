//
//  LocalCurrencyDataSource.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

/// Протокол для локального источника данных валют
protocol LocalCurrencyDataSource: Sendable {
    func loadCachedRate(from: String, to: String) async throws -> CachedRate?
    func saveRate(from: String, to: String, rate: Double) async throws
    func loadCachedCurrencies() async throws -> [String: Currency]?
    func loadCachedCurrencyList() async throws -> CachedCurrencyList?
    func saveCachedCurrencies(_ currencies: [String: Currency]) async throws
    func clearCachedCurrencies() async throws
}

// MARK: - Default Implementation

extension LocalCurrencyDataSource {
    func loadCachedCurrencies() async throws -> [String: Currency]? { nil }
    func loadCachedCurrencyList() async throws -> CachedCurrencyList? {
        guard let currencies = try await loadCachedCurrencies() else { return nil }
        return CachedCurrencyList(currencies: currencies, updatedAt: .now)
    }
    func saveCachedCurrencies(_ currencies: [String: Currency]) async throws {}
    func clearCachedCurrencies() async throws {}
}

extension CurrencyLocalDataSource: LocalCurrencyDataSource {
}
