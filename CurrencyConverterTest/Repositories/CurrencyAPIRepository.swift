//
//  CurrencyAPIRepository.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftData
import Foundation

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

enum CurrencyAPIRepositoryError: Error {
    case missingAPIKey
    case invalidCurrencyCodes
    case invalidAmount
    case noCacheAvailable
}

// MARK: - CurrencyAPIRepository

final class CurrencyAPIRepository: CurrencyRepository {
    // MARK: - Properties

    private let cacheTTL: TimeInterval
    private let context: ModelContext
    private let localDataSource: CurrencyLocalDataStoring
    private let networkService: CurrencyNetworking
    private let apiKeyProvider: APIKeyProviding
    private let apiKey: String
    private let apiBaseURL: URL

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
            Logger.log("API ключ пустой")
            throw CurrencyAPIRepositoryError.missingAPIKey
        }
    }

    // MARK: - CurrencyRemoteDataSource

    /// Загружает список поддерживаемых валют.
    /// - Returns: Словарь валют с их кодами и данными.
    /// - Throws: Ошибка при сетевом запросе или декодировании.
    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        do {
            let endpoint = CurrencyAPIEndpoint.currencies(apiKey: apiKey, baseURL: apiBaseURL)
            let data = try await networkService.request(endpoint)
            let decoded: CurrencyResponse = try networkService.decode(data)
            Logger.log("Успешно получено: \(decoded.data.count) валют")
            return decoded.data
        } catch let decodingError as DecodingError {
            throw decodingError
        } catch {
            Logger.log("Ошибка при получении валют: \(error)")
            throw error
        }
    }

    /// Конвертирует сумму из одной валюты в другую с использованием кэша или сетевого запроса.
    /// - Parameters:
    ///   - from: Код исходной валюты.
    ///   - to: Код целевой валюты.
    ///   - amount: Сумма для конвертации.
    /// - Returns: Результат конвертации с курсом.
    /// - Throws: Ошибка при некорректных данных, сетевом запросе или отсутствии кэша.
    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        guard !from.isEmpty, !to.isEmpty else {
            throw CurrencyAPIRepositoryError.invalidCurrencyCodes
        }
        guard amount >= 0, !amount.isNaN else {
            throw CurrencyAPIRepositoryError.invalidAmount
        }

        do {
            if let cached = try localDataSource.loadCachedRate(from: from, to: to),
               Date().timeIntervalSince(cached.timestamp) < cacheTTL {
                Logger.log("Использование кешированного курса для \(from)/\(to)")
                return ConversionResult(result: amount * cached.rate, rate: cached.rate)
            }

            return try await fetchAndCacheConversion(from: from, to: to, amount: amount)
        } catch let decodingError as DecodingError {
            throw decodingError
        } catch {
            Logger.log("Ошибка при конвертации, попытка fallback: \(error)")
            if let cached = try? localDataSource.loadCachedRate(from: from, to: to) {
                Logger.log("Использование кешированного курса в fallback для \(from)/\(to)")
                return ConversionResult(result: amount * cached.rate, rate: cached.rate)
            } else {
                throw CurrencyAPIRepositoryError.noCacheAvailable
            }
        }
    }

    // MARK: - Private Helpers

    private func fetchAndCacheConversion(from: String, to: String, amount: Double) async throws -> ConversionResult {
        do {
            let endpoint = CurrencyAPIEndpoint.convert(from: from, to: to, apiKey: apiKey, baseURL: apiBaseURL)
            let data = try await networkService.request(endpoint)
            let decoded: CurrencyAPIResponse = try networkService.decode(data)

            guard let rateObj = decoded.data[to] else {
                let errorMsg = "Нет курса для выбранной валюты: \(to)"
                Logger.log(errorMsg)
                throw NSError(domain: "CurrencyAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }

            let rate = rateObj.value
            Logger.log("Курс \(from)/\(to): \(rate)")

            try localDataSource.saveRate(from: from, to: to, rate: rate)
            Logger.log("Курс успешно сохранен в кэш: \(from)/\(to)")

            return ConversionResult(result: amount * rate, rate: rate)
        } catch let decodingError as DecodingError {
            throw decodingError
        } catch {
            Logger.log("Ошибка при fetchAndCacheConversion: \(error)")
            throw error
        }
    }

    // MARK: - Save Conversion

    /// Сохраняет результат конверсии в контекст SwiftData.
    /// - Parameter conversion: Объект конверсии для сохранения.
    func saveConversion(_ conversion: Conversion) async {
        context.insert(conversion)
        do {
            try context.save()
            Logger.log("Конверсия успешно сохранена")
        } catch {
            Logger.log("Ошибка при сохранении контекста: \(error)")
        }
    }
}

// MARK: - NetworkService CurrencyNetworking Conformance
extension NetworkService: CurrencyNetworking {}
