//
//  CurrencyAPIRepository.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftData
import Foundation

// MARK: - Protocols

protocol CurrencyLocalDataStoring {
    func loadCachedRate(from: String, to: String) throws -> ExchangeRate?
    func saveRate(from: String, to: String, rate: Double) throws
}

protocol CurrencyNetworking {
    func request(_ endpoint: APIEndpointProtocol) async throws -> Data
    func decode<T: Decodable>(_ data: Data) throws -> T
}

protocol APIKeyProviding {
    func loadAPIKey() -> String?
    func saveAPIKey(_ key: String)
    func initializeAPIKeyIfNeeded()
}

// MARK: - CurrencyAPI Repository

final class CurrencyAPIRepository {
    
    // MARK: - Property
    
    private let cacheTTL: TimeInterval
    private let context: ModelContext
    private let localDataSource: CurrencyLocalDataStoring
    private let networkService: CurrencyNetworking
    private let apiKeyProvider: APIKeyProviding
    private let apiKey: String
    private let apiBaseURL: URL
    
    // MARK: - Initialization
    
    init(context: ModelContext,
         localDataSource: CurrencyLocalDataStoring,
         networkService: CurrencyNetworking,
         apiKeyProvider: APIKeyProviding,
         apiKey: String,
         apiBaseURL: URL,
         cacheTTL: TimeInterval = 3600) throws {
        
        self.context = context
        self.localDataSource = localDataSource
        self.networkService = networkService
        self.apiKeyProvider = apiKeyProvider
        self.apiKey = apiKey
        self.apiBaseURL = apiBaseURL
        self.cacheTTL = cacheTTL
        
        apiKeyProvider.initializeAPIKeyIfNeeded()
        
        guard !apiKey.isEmpty else {
            Logger.log("Ошибка: API ключ не найден")
            throw AppError.configurationError("Отсутствует API ключ")
        }
    }
    
    // MARK: - Public methods
    
    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        let endpoint = CurrencyAPIEndpoint.currencies(
            apiKey: apiKey,
            baseURL: apiBaseURL
        )
        
        let data = try await networkService.request(endpoint)
        let decoded: CurrencyResponse = try networkService.decode(data)
        
        Logger.log("Загружено валют: \(decoded.data.count)")
        return decoded.data
    }
    
    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        guard !from.isEmpty, !to.isEmpty else {
            throw AppError.validationError("Не указаны валюты для конвертации")
        }
        
        guard amount >= 0, !amount.isNaN else {
            throw AppError.validationError("Некорректная сумма: \(amount)")
        }
        
        // Пробуем получить курс из кэша
        if let cached = try localDataSource.loadCachedRate(from: from, to: to),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            Logger.log("Используем кэшированный курс \(from)/\(to)")
            return ConversionResult(result: amount * cached.rate, rate: cached.rate)
        }
        
        // Если кэша нет или он устарел - запрашиваем из сети
        do {
            let result = try await fetchAndCacheConversion(from: from, to: to, amount: amount)
            return result
        } catch {
            Logger.log("Ошибка при запросе курса: \(error)")
            
            // Fallback: пытаемся использовать старый кэш, если есть
            if let cached = try? localDataSource.loadCachedRate(from: from, to: to) {
                Logger.log("Используем устаревший кэш \(from)/\(to) как fallback")
                return ConversionResult(result: amount * cached.rate, rate: cached.rate)
            }
            
            throw AppError.networkError(error)
        }
    }
    
    func saveConversion(_ conversion: Conversion) async {
        context.insert(conversion)
        
        do {
            try context.save()
            Logger.log("Конверсия сохранена")
        } catch {
            Logger.log("Не удалось сохранить конверсию: \(error)")
        }
    }
    
    // MARK: - Private methods
    
    private func fetchAndCacheConversion(from: String, to: String, amount: Double) async throws -> ConversionResult {
        let endpoint = CurrencyAPIEndpoint.convert(
            from: from,
            to: to,
            apiKey: apiKey,
            baseURL: apiBaseURL
        )
        
        let data = try await networkService.request(endpoint)
        let decoded: CurrencyAPIResponse = try networkService.decode(data)
        
        guard let rateObj = decoded.data[to] else {
            throw AppError.dataError("Нет курса для валюты \(to)")
        }
        
        let rate = rateObj.value
        Logger.log("Получен курс \(from)/\(to): \(rate)")
        
        // Сохраняем в кэш
        try localDataSource.saveRate(from: from, to: to, rate: rate)
        Logger.log("Курс сохранен в кэш")
        
        return ConversionResult(result: amount * rate, rate: rate)
    }
}

// MARK: - CurrencyRepository protocol

extension CurrencyAPIRepository: CurrencyRepository {
    // Реализация уже есть в основных методах класса
}

// MARK: - Extension for NetworkService

extension NetworkService: CurrencyNetworking {
    // Реализация методов протокола уже есть в NetworkService
}
