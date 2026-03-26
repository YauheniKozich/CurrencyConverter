//
//  CurrencyCacheManager.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation
import SwiftData

/// Менеджер кэширования валютных курсов
actor CurrencyCacheManager {

    private let localDataSource: any LocalCurrencyDataSource
    private let cacheTTL: TimeInterval

    private var cachedCurrencies: [String: Currency]?
    private var currenciesLoadTask: Task<[String: Currency], Error>?
    private var lastCurrenciesHash: Int?
    private var currenciesGeneration: UInt64 = 0

    init(
        localDataSource: any LocalCurrencyDataSource,
        cacheTTL: TimeInterval = ConfigurationDefaults.cacheTTL
    ) {
        self.localDataSource = localDataSource
        self.cacheTTL = cacheTTL
    }

    func getCurrencies(
        load: @escaping @Sendable () async throws -> [String: Currency],
        forceRefresh: Bool = false
    ) async throws -> [String: Currency] {
        if forceRefresh {
            invalidateCurrenciesCache()
        }

        if let cached = cachedCurrencies, !forceRefresh {
            Logger.log("Валюты из in-memory кэша: \(cached.count)", level: .debug)
            return cached
        }

        if let existingTask = currenciesLoadTask {
            Logger.log("Ждём завершения загрузки валют", level: .debug)
            return try await existingTask.value
        }

        let requestGeneration = currenciesGeneration
        currenciesLoadTask = Task {
            do {
                let currencies = try await load()

                return commitLoadedCurrencies(
                    currencies,
                    generation: requestGeneration,
                    forceRefresh: forceRefresh
                )
            } catch {
                clearLoadTaskIfCurrent(generation: requestGeneration)
                throw error
            }
        }

        return try await currenciesLoadTask!.value
    }

    func invalidateCurrenciesCache() {
        currenciesGeneration &+= 1
        currenciesLoadTask?.cancel()
        cachedCurrencies = nil
        currenciesLoadTask = nil
        lastCurrenciesHash = nil
    }

    func getCachedRate(from: String, to: String) throws -> Double? {
        guard let cached = try localDataSource.loadCachedRate(from: from, to: to),
              Date().timeIntervalSince(cached.timestamp) < cacheTTL else {
            return nil
        }

        Logger.log("Используем кэшированный курс \(from)/\(to)", level: .debug)
        return cached.rate
    }

    func getStaleCachedRate(from: String, to: String) throws -> Double? {
        guard let cached = try? localDataSource.loadCachedRate(from: from, to: to) else {
            return nil
        }

        Logger.log("Используем устаревший кэш \(from)/\(to) как fallback", level: .warning)
        return cached.rate
    }

    func saveRate(from: String, to: String, rate: Double) {
        do {
            try localDataSource.saveRate(from: from, to: to, rate: rate)
            Logger.log("Курс сохранен в кэш", level: .debug)
        } catch {
            Logger.log("Не удалось сохранить курс в кэш: \(error)", level: .error)
        }
    }

    private func calculateCurrenciesHash(_ currencies: [String: Currency]) -> Int {
        let sortedCodes = currencies.keys.sorted()
        return sortedCodes.hashValue
    }

    private func commitLoadedCurrencies(
        _ currencies: [String: Currency],
        generation: UInt64,
        forceRefresh: Bool
    ) -> [String: Currency] {
        guard generation == currenciesGeneration else {
            Logger.log("Игнорируем устаревшую загрузку валют", level: .debug)
            return cachedCurrencies ?? currencies
        }

        let currentHash = calculateCurrenciesHash(currencies)

        if let lastHash = lastCurrenciesHash,
           currentHash == lastHash && !forceRefresh {
            Logger.log("Данные не изменились, используем кэш", level: .debug)
            currenciesLoadTask = nil
            return cachedCurrencies ?? currencies
        }

        Logger.log("Данные обновились, обновляем кэш", level: .debug)
        cachedCurrencies = currencies
        lastCurrenciesHash = currentHash
        currenciesLoadTask = nil
        return currencies
    }

    private func clearLoadTaskIfCurrent(generation: UInt64) {
        guard generation == currenciesGeneration else { return }
        currenciesLoadTask = nil
    }
}
