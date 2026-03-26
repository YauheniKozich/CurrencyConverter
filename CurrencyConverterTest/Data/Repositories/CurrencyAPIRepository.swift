//
//  CurrencyAPIRepository.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - CurrencyAPI Repository

final class CurrencyAPIRepository: CurrencyRepository, @unchecked Sendable {

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
        let apiKey = self.apiKey
        let apiBaseURL = self.apiBaseURL
        let networkService = self.networkService

        return try await cacheManager.getCurrencies(
            load: {
                let endpoint = CurrencyAPIEndpoint.currencies(
                    apiKey: apiKey,
                    baseURL: apiBaseURL
                )

                let data = try await networkService.request(endpoint)
                let decoded: CurrencyResponse = try networkService.decode(data)

                Logger.log("Загружено валют: \(decoded.data.count)", level: .info)
                return decoded.data
            },
            forceRefresh: false
        )
    }

    func refreshSupportedCurrencies() async throws -> [String: Currency] {
        let apiKey = self.apiKey
        let apiBaseURL = self.apiBaseURL
        let networkService = self.networkService

        return try await cacheManager.getCurrencies(
            load: {
                let endpoint = CurrencyAPIEndpoint.currencies(
                    apiKey: apiKey,
                    baseURL: apiBaseURL
                )

                let data = try await networkService.request(endpoint)
                let decoded: CurrencyResponse = try networkService.decode(data)

                Logger.log("Загружено валют: \(decoded.data.count)", level: .info)
                return decoded.data
            },
            forceRefresh: true
        )
    }

    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        if let cachedRate = try await cacheManager.getCachedRate(from: from, to: to) {
            return ConversionResult(result: amount * cachedRate, rate: cachedRate)
        }

        do {
            let result = try await fetchAndCacheConversion(from: from, to: to, amount: amount)
            return result
        } catch let appError as AppError {
            Logger.log("Ошибка конвертации: \(appError.failureReason ?? "")", level: .error)

            if appError.isRecoverable,
               let staleRate = try? await cacheManager.getStaleCachedRate(from: from, to: to) {
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

            guard let currencyValue = decoded.data[to] else {
                throw AppError.dataNotFound
            }

            let rate = currencyValue.value

            Logger.log("Получен курс \(from)/\(to): \(rate)", level: .debug)

            await cacheManager.saveRate(from: from, to: to, rate: rate)

            return ConversionResult(result: amount * rate, rate: rate)
        } catch let networkError as NetworkError {
            throw networkError.appError
        }
    }
}
