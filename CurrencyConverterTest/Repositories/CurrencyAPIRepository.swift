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
    private(set) var apiKey: String
    private let baseURL = "https://api.currencyapi.com/v3/latest"
    private let cacheTTL: TimeInterval = 3600 // 1 час
    private let context: ModelContext
    private let localDataSource: CurrencyLocalDataSource
    
    init(context: ModelContext) {
        self.context = context
        self.localDataSource = CurrencyLocalDataSource(context: context)
        
        guard let loadedKey = APIKeyLoader.loadAPIKey() else {
            fatalError("API ключ не найден и не может быть загружен из Config.plist")
        }
        
        self.apiKey = loadedKey
        saveApiKeyToKeychain(loadedKey)
    }
    
    // MARK: - CurrencyRemoteDataSource
    
    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        guard let url = APIEndpoint.currencies(key: apiKey) else {
            throw URLError(.badURL)
        }
        log("Запрос к: \(url)")
        let session = makeSession()
        let (data, response) = try await performWithRetry {
            try await session.data(from: url)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        switch httpResponse.statusCode {
        case 200...299:
            let decoded = try JSONDecoder().decode(CurrencyResponse.self, from: data)
            log("Успешно получено: \(decoded.data.count) валют")
            return decoded.data
        case 429:
            throw URLError(.dataNotAllowed)
        case 500...599:
            throw URLError(.badServerResponse)
        default:
            throw URLError(.unknown)
        }
    }
    
    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        if let cached = try? localDataSource.loadCachedRate(from: from, to: to), Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return ConversionResult(result: amount * cached.rate, rate: cached.rate)
        }
        guard let url = APIEndpoint.latest(from: from, to: to, key: apiKey) else {
            throw URLError(.badURL)
        }
        log("Отправляем запрос на конвертацию из \(from) в \(to) суммы \(amount)")
        let session = makeSession()
        do {
            let (data, response) = try await performWithRetry {
                try await session.data(from: url)
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(CurrencyAPIResponse.self, from: data)
            guard let rateObj = decoded.data[to] else {
                throw NSError(domain: "CurrencyAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Нет курса для выбранной валюты"])
            }
            let rate = rateObj.value
            log("Курс \(from)/\(to): \(rate)")
            try? localDataSource.saveRate(from: from, to: to, rate: rate)
            return ConversionResult(result: amount * rate, rate: rate)
        } catch {
            if let fallback = try? localDataSource.loadCachedRate(from: from, to: to) {
                return ConversionResult(result: amount * fallback.rate, rate: fallback.rate)
            }
            throw error
        }
    }
    
    // MARK: - CurrencyLocalDataSource
    
    // MARK: - KeychainHelper
    
    private func saveApiKeyToKeychain(_ key: String) {
        KeychainHelper.shared.saveString(key, service: service, account: account)
    }
    
    // MARK: - URLSession Configuration
    
    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Alt-Used": "api.currencyapi.com"
        ]
        configuration.multipathServiceType = .interactive
        return URLSession(configuration: configuration)
    }
}

// MARK: - Retry Logic
private func performWithRetry<T>(maxRetries: Int = 5, delayFactor: Double = 0.5, operation: @escaping () async throws -> T) async throws -> T {
    var retryCount = 0
    while retryCount < maxRetries {
        do {
            return try await operation()
        } catch {
            retryCount += 1
            if retryCount >= maxRetries { throw error }
            let delay = pow(2.0, Double(retryCount)) * delayFactor
            log("Повтор \(retryCount)/\(maxRetries) через \(delay)s")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
    throw URLError(.unknown)
}

// MARK: - Logging
private func log(_ message: String) {
#if DEBUG
    print("🔹 \(message)")
#endif
}
