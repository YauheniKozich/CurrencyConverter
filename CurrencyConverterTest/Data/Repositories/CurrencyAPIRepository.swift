//
//  CurrencyAPIRepository.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - CurrencyAPI Repository

final class CurrencyAPIRepository: CurrencyRepository {

    // MARK: - Properties

    private let cacheManager: CurrencyCacheManager
    private let networkService: NetworkService
    private let apiKey: String
    private let apiBaseURL: URL

    // MARK: - Initialization

    init(localDataSource: LocalCurrencyDataSource,
         networkService: NetworkService,
         apiKey: String,
         apiBaseURL: URL,
         cacheTTL: TimeInterval = 3600) throws {

        self.cacheManager = CurrencyCacheManager(
            localDataSource: localDataSource,
            cacheTTL: cacheTTL
        )
        self.networkService = networkService
        self.apiKey = apiKey
        self.apiBaseURL = apiBaseURL

        guard !apiKey.isEmpty else {
            Logger.log("Ошибка: API ключ не найден", level: .error)
            throw AppError.configurationError(message: "Отсутствует API ключ")
        }
    }

    // MARK: - CurrencyRepository Conformance

    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        try await cacheManager.getCurrencies(
            load: { [weak self] in
                guard let self = self else { return [:] }
                
                let endpoint = CurrencyAPIEndpoint.currencies(
                    apiKey: self.apiKey,
                    baseURL: self.apiBaseURL
                )

                let data = try await self.networkService.request(endpoint)
                let decoded: CurrencyResponse = try self.networkService.decode(data)

                Logger.log("Загружено валют: \(decoded.data.count)", level: .info)
                return decoded.data
            },
            forceRefresh: false
        )
    }

    func refreshSupportedCurrencies() async throws -> [String: Currency] {
        try await cacheManager.getCurrencies(
            load: { [weak self] in
                guard let self = self else { return [:] }
                
                let endpoint = CurrencyAPIEndpoint.currencies(
                    apiKey: self.apiKey,
                    baseURL: self.apiBaseURL
                )

                let data = try await self.networkService.request(endpoint)
                let decoded: CurrencyResponse = try self.networkService.decode(data)

                Logger.log("Загружено валют: \(decoded.data.count)", level: .info)
                return decoded.data
            },
            forceRefresh: true
        )
    }

    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        // Пробуем получить курс из кэша
        if let cachedRate = try cacheManager.getCachedRate(from: from, to: to) {
            return ConversionResult(result: amount * cachedRate, rate: cachedRate)
        }

        // Если кэша нет или он устарел - запрашиваем из сети
        do {
            let result = try await fetchAndCacheConversion(from: from, to: to, amount: amount)
            return result
        } catch let appError as AppError {
            Logger.log("Ошибка конвертации: \(appError.failureReason ?? "")", level: .error)

            // Fallback: пытаемся использовать старый кэш, если ошибка recoverable
            if appError.isRecoverable,
               let staleRate = try? cacheManager.getStaleCachedRate(from: from, to: to) {
                return ConversionResult(result: amount * staleRate, rate: staleRate)
            }

            throw appError
        } catch {
            Logger.log("Неизвестная ошибка конвертации: \(error)", level: .error)
            throw AppError.unknown(error)
        }
    }

    // MARK: - Private Methods

    private func fetchAndCacheConversion(from: String, to: String, amount: Double) async throws -> ConversionResult {
        do {
            let endpoint = CurrencyAPIEndpoint.convert(
                from: from,
                to: to,
                apiKey: apiKey,
                baseURL: apiBaseURL
            )

            let data = try await networkService.request(endpoint)
            let decoded: CurrencyAPIResponse = try networkService.decode(data)

            // Извлекаем курс для целевой валюты из словаря
            guard let currencyValue = decoded.data[to] else {
                throw AppError.dataNotFound
            }

            let rate = currencyValue.value

            Logger.log("Получен курс \(from)/\(to): \(rate)", level: .debug)

            // Сохраняем в кэш
            cacheManager.saveRate(from: from, to: to, rate: rate)

            return ConversionResult(result: amount * rate, rate: rate)
        } catch let networkError as NetworkError {
            // Маппим NetworkError на AppError
            throw networkError.appError
        }
    }
}
