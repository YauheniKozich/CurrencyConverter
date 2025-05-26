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
}

enum CurrencyAPIRepositoryError: Error {
    case missingAPIKey
}

// MARK: - CurrencyAPIRepository

final class CurrencyAPIRepository: CurrencyRepository {
    // MARK: - Properties

    private let cacheTTL: TimeInterval = 3600
    private let context: ModelContext
    private let localDataSource: CurrencyLocalDataStoring
    private let networkService: CurrencyNetworking
    private let apiKeyProvider: APIKeyProviding
    private let apiKey: String

    init(context: ModelContext,
         localDataSource: CurrencyLocalDataStoring,
         networkService: CurrencyNetworking,
         apiKeyProvider: APIKeyProviding) throws {
        self.context = context
        self.localDataSource = localDataSource
        self.networkService = networkService
        self.apiKeyProvider = apiKeyProvider

        guard let loadedKey = apiKeyProvider.loadAPIKey() else {
            Logger.log("API ключ не найден и не может быть загружен из APIKeyProvider")
            throw CurrencyAPIRepositoryError.missingAPIKey
        }

        self.apiKey = loadedKey
        apiKeyProvider.saveAPIKey(loadedKey)
    }

    // MARK: - CurrencyRemoteDataSource

    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        do {
            let data = try await networkService.request(CurrencyAPIEndpoint.currencies(apiKey: apiKey))
            let decoded: CurrencyResponse = try networkService.decode(data)
            Logger.log("Успешно получено: \(decoded.data.count) валют")
            return decoded.data
        } catch {
            Logger.log("Ошибка при получении валют: \(error)")
            throw error
        }
    }

    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        if let cached = try? localDataSource.loadCachedRate(from: from, to: to),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            Logger.log("Использование кешированного курса для \(from)/\(to)")
            return ConversionResult(result: amount * cached.rate, rate: cached.rate)
        }

        do {
            return try await fetchAndCacheConversion(from: from, to: to, amount: amount)
        } catch {
            do {
                return try await fallbackConversion(from: from, to: to, amount: amount)
            } catch {
                Logger.log("Ошибка при конвертации и fallback: \(error)")
                throw error
            }
        }
    }

    // MARK: - Private Helpers

    private func fetchAndCacheConversion(from: String, to: String, amount: Double) async throws -> ConversionResult {
        let data = try await networkService.request(CurrencyAPIEndpoint.convert(from: from, to: to, apiKey: apiKey))
        let decoded: CurrencyAPIResponse = try networkService.decode(data)

        guard let rateObj = decoded.data[to] else {
            let errorMsg = "Нет курса для выбранной валюты: \(to)"
            Logger.log(errorMsg)
            throw NSError(domain: "CurrencyAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        let rate = rateObj.value
        Logger.log("Курс \(from)/\(to): \(rate)")

        do {
            try localDataSource.saveRate(from: from, to: to, rate: rate)
        } catch {
            Logger.log("Ошибка при сохранении кеша: \(error)")
        }

        return ConversionResult(result: amount * rate, rate: rate)
    }

    private func fallbackConversion(from: String, to: String, amount: Double) async throws -> ConversionResult {
        do {
            guard let fallback = try localDataSource.loadCachedRate(from: from, to: to) else {
                throw NSError(domain: "CurrencyAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Нет доступного кеша для fallback"])
            }
            Logger.log("Использование кешированного курса в fallback для \(from)/\(to)")
            return ConversionResult(result: amount * fallback.rate, rate: fallback.rate)
        } catch {
            throw error
        }
    }
}

// MARK: - CurrencyAPIRepository Extension
extension CurrencyAPIRepository {
    func saveConversion(_ conversion: Conversion) async {
        context.insert(conversion)
        do {
            try context.save()
        } catch {
            Logger.log("Ошибка при сохранении контекста: \(error)")
        }
    }
}

// MARK: - NetworkService CurrencyNetworking Conformance
extension NetworkService: CurrencyNetworking {}
