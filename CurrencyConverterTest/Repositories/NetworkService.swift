//
//  APIEndpoint.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - NetworkError

enum NetworkError: Error {
    case invalidResponse
    case statusCodeError(Int)
    case decodingError(Error)
    case unknown
}

// MARK: - APIEndpointProtocol

protocol APIEndpointProtocol {
    var urlRequest: URLRequest { get }
}

// MARK: - CurrencyAPIEndpoint

enum CurrencyAPIEndpoint: APIEndpointProtocol {
    case currencies(apiKey: String)
    case convert(from: String, to: String, apiKey: String)
    
    var urlRequest: URLRequest {
        switch self {
        case .currencies(let apiKey):
            var components = URLComponents(string: "https://api.currencyapi.com/v3/currencies")!
            components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
            let url = components.url!
            return URLRequest(url: url)
        case .convert(let from, let to, let apiKey):
            var components = URLComponents(string: "https://api.currencyapi.com/v3/latest")!
            components.queryItems = [
                URLQueryItem(name: "base_currency", value: from),
                URLQueryItem(name: "currencies", value: to),
                URLQueryItem(name: "apikey", value: apiKey)
            ]
            let url = components.url!
            return URLRequest(url: url)
        }
    }
}

// MARK: - NetworkService

final class NetworkService {
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Alt-Used": "api.currencyapi.com"
        ]
        configuration.multipathServiceType = .interactive
        self.session = URLSession(configuration: configuration)
    }
    
    func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            log("Ошибка декодирования: \(error)")
            throw NetworkError.decodingError(error)
        }
    }
    
    func request(_ endpoint: APIEndpointProtocol) async throws -> Data {
        return try await performWithRetry {
            self.log("Запрос к: \(endpoint.urlRequest.url?.absoluteString ?? "unknown URL")")
            let (data, response) = try await self.session.data(for: endpoint.urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                self.log("Ошибка: неверный ответ сервера")
                throw NetworkError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                self.log("Ошибка: статус код \(httpResponse.statusCode)")
                throw NetworkError.statusCodeError(httpResponse.statusCode)
            }
            return data
        }
    }
    
    // MARK: - Retry Logic решение для Api так как оно не очень хорошее
    private func performWithRetry<T>(maxRetries: Int = 5, delayFactor: Double = 0.5, operation: @escaping () async throws -> T) async throws -> T {
        var retryCount = 0
        while retryCount < maxRetries {
            do {
                return try await operation()
            } catch {
                retryCount += 1
                if retryCount >= maxRetries {
                    log("Достигнуто максимальное количество повторов: \(retryCount). Ошибка: \(error)")
                    throw error
                }
                let delay = pow(2.0, Double(retryCount)) * delayFactor
                log("Повтор \(retryCount)/\(maxRetries) через \(delay)s из-за ошибки: \(error)")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        log("Неизвестная ошибка после повторов")
        throw NetworkError.unknown
    }
    
    // MARK: - Logging
    private func log(_ message: String) {
    #if DEBUG
        print("🔹 \(message)")
    #endif
    }
}
