//
//  CurrencyCacheManager.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation
import SwiftData

/// Менеджер кэширования валютных курсов
final class CurrencyCacheManager {

    private let localDataSource: LocalCurrencyDataSource
    private let cacheTTL: TimeInterval

    // In-memory кэш для валют
    private var cachedCurrencies: [String: Currency]?
    private var currenciesLoadTask: Task<[String: Currency], Error>?

    // Хэш последних загруженных данных для сравнения
    private var lastCurrenciesHash: Int?

    init(
        localDataSource: LocalCurrencyDataSource,
        cacheTTL: TimeInterval = 3600
    ) {
        self.localDataSource = localDataSource
        self.cacheTTL = cacheTTL
    }

    // MARK: - Currency List Cache

    /// Загружает валюты с умным кэшированием
    /// - Parameters:
    ///   - load: Closure для загрузки из сети
    ///   - forceRefresh: Принудительное обновление (игнорируем кэш)
    /// - Returns: Список валют
    /// - Note: Если данные не изменились — возвращаем из кэша
    func getCurrencies(
        load: @escaping () async throws -> [String: Currency],
        forceRefresh: Bool = false
    ) async throws -> [String: Currency] {
        // Если force refresh — инвалидируем кэш
        if forceRefresh {
            invalidateCurrenciesCache()
        }

        // Возвращаем из in-memory кэша если есть
        if let cached = cachedCurrencies, !forceRefresh {
            Logger.log("Валюты из in-memory кэша: \(cached.count)", level: .debug)
            return cached
        }

        // Если уже идёт загрузка — ждём её
        if let existingTask = currenciesLoadTask {
            Logger.log("Ждём завершения загрузки валют", level: .debug)
            return try await existingTask.value
        }

        // Загружаем валюты
        currenciesLoadTask = Task {
            do {
                let currencies = try await load()
                
                // Проверяем изменились ли данные (сравниваем hash кодов валют)
                let currentHash = calculateCurrenciesHash(currencies)
                
                if let lastHash = lastCurrenciesHash,
                   currentHash == lastHash && !forceRefresh {
                    // Данные не изменились — возвращаем кэш
                    Logger.log("Данные не изменились, используем кэш", level: .debug)
                    currenciesLoadTask = nil
                    return cachedCurrencies ?? currencies
                }
                
                // Данные изменились — обновляем кэш
                Logger.log("Данные обновились, обновляем кэш", level: .debug)
                cachedCurrencies = currencies
                lastCurrenciesHash = currentHash
                currenciesLoadTask = nil
                return currencies
            } catch {
                currenciesLoadTask = nil
                throw error
            }
        }

        return try await currenciesLoadTask!.value
    }
    
    /// Вычисляет хэш списка валют для сравнения
    private func calculateCurrenciesHash(_ currencies: [String: Currency]) -> Int {
        // Сортируем коды валют и вычисляем hash
        let sortedCodes = currencies.keys.sorted()
        return sortedCodes.hashValue
    }

    func invalidateCurrenciesCache() {
        cachedCurrencies = nil
        currenciesLoadTask = nil
        lastCurrenciesHash = nil
    }
    
    // MARK: - Exchange Rate Cache
    
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
        try? localDataSource.saveRate(from: from, to: to, rate: rate)
        Logger.log("Курс сохранен в кэш", level: .debug)
    }
}
