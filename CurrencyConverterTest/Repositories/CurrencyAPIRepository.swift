//
//  CurrencyAPIRepository.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI
import SwiftData

// MARK: - CurrencyAPIRepository

final class CurrencyAPIRepository: CurrencyRepository {
    // MARK: - Properties
    
    private let service = "com.yourapp.currencyconverter"
    private let account = "CurrencyAPIKey"
    private(set) var apiKey: String?
    private let cacheTTL: TimeInterval = 3600 // 1 час
    private var context: ModelContext {
        didSet {
            localDataSource = CurrencyLocalDataSource(context: context)
        }
    }
    private var localDataSource: CurrencyLocalDataSource
    private let networkService: NetworkService
    
    init?(context: ModelContext) {
        self.context = context
        self.localDataSource = CurrencyLocalDataSource(context: context)
        self.networkService = NetworkService()
        
        guard let loadedKey = APIKeyLoader.loadAPIKey() else {
            log("API ключ не найден и не может быть загружен из Config.plist")
            return nil
        }
        
        self.apiKey = loadedKey
        saveApiKeyToKeychain(loadedKey)
    }
    
    // MARK: - CurrencyRemoteDataSource
    
    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        do {
            let data = try await networkService.request(CurrencyAPIEndpoint.currencies(apiKey: apiKey ?? "" ))
            let decoded: CurrencyResponse = try networkService.decode(data)
            log("Успешно получено: \(decoded.data.count) валют")
            return decoded.data
        } catch {
            log("Ошибка при получении валют: \(error)")
            throw error
        }
    }
    
    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        if let cached = try? localDataSource.loadCachedRate(from: from, to: to),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            log("Использование кешированного курса для \(from)/\(to)")
            return ConversionResult(result: amount * cached.rate, rate: cached.rate)
        }

        do {
            let data = try await networkService.request(CurrencyAPIEndpoint.convert(from: from, to: to, apiKey: apiKey ?? ""))
            let decoded: CurrencyAPIResponse = try networkService.decode(data)

            guard let rateObj = decoded.data[to] else {
                let errorMsg = "Нет курса для выбранной валюты: \(to)"
                log(errorMsg)
                throw NSError(domain: "CurrencyAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }

            let rate = rateObj.value
            log("Курс \(from)/\(to): \(rate)")
            try? localDataSource.saveRate(from: from, to: to, rate: rate)
            return ConversionResult(result: amount * rate, rate: rate)
        } catch {
            log("Ошибка при конвертации: \(error)")

            if let fallback = try? localDataSource.loadCachedRate(from: from, to: to) {
                log("Использование кешированного курса в fallback для \(from)/\(to)")
                return ConversionResult(result: amount * fallback.rate, rate: fallback.rate)
            }

            throw error
        }
    }
    
    // MARK: - KeychainHelper
    
    private func saveApiKeyToKeychain(_ key: String) {
        KeychainHelper.shared.saveString(key, service: service, account: account)
    }
}

// MARK: - Logging
private func log(_ message: String) {
#if DEBUG
    print("🔹 \(message)")
#endif
}

// MARK: - CurrencyAPIRepository Extension
extension CurrencyAPIRepository {
    func saveConversion(_ conversion: Conversion) async {
        context.insert(conversion)
    }
}
