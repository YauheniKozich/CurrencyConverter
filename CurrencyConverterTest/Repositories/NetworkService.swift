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
        var components: URLComponents
        switch self {
        case .currencies(let apiKey):
            components = URLComponents(string: "https://api.currencyapi.com/v3/currencies")!
            components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
        case .convert(let from, let to, let apiKey):
            components = URLComponents(string: "https://api.currencyapi.com/v3/latest")!
            components.queryItems = [
                URLQueryItem(name: "base_currency", value: from),
                URLQueryItem(name: "currencies", value: to),
                URLQueryItem(name: "apikey", value: apiKey)
            ]
        }
        let url = components.url!
        return URLRequest(url: url)
    }
}

// MARK: - NetworkService

final class NetworkService {
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    
    init(session: URLSession = NetworkService.makeDefaultSession(),
         decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.jsonDecoder = decoder
    }
    
    private static func makeDefaultSession() -> URLSession {
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
    
    func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            Logger.log("Ошибка декодирования: \(error)")
            throw NetworkError.decodingError(error)
        }
    }
    
    func request(_ endpoint: APIEndpointProtocol) async throws -> Data {
        try await performWithRetry {
            Logger.log("Выполняется запрос: \(endpoint.urlRequest.url?.absoluteString ?? "unknown URL")")
            
            let (data, response) = try await self.session.data(for: endpoint.urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.log("Ошибка: неверный ответ сервера")
                throw NetworkError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                Logger.log("Ошибка: статус код \(httpResponse.statusCode)")
                throw NetworkError.statusCodeError(httpResponse.statusCode)
            }
            
            return data
        }
    }
    
    // MARK: - Retry Logic
    
    private func performWithRetry<T>(
        maxRetries: Int = 5,
        initialDelay: Double = 0.5,
        maxDelay: Double = 10,
        shouldRetry: @escaping (Error) -> Bool = { _ in true },
        onRetry: ((Int, Error) -> Void)? = nil,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var retryCount = 0
        
        while true {
            try Task.checkCancellation()
            do {
                return try await operation()
            } catch {
                retryCount += 1
                if retryCount > maxRetries || !shouldRetry(error) {
                    Logger.log("Прекращение повторов после \(retryCount - 1) попыток. Ошибка: \(error)")
                    throw error
                }
                
                let delay = min(pow(2.0, Double(retryCount)) * initialDelay, maxDelay)
                Logger.log("Повтор \(retryCount)/\(maxRetries) через \(String(format: "%.2f", delay)) секунд из-за ошибки: \(error)")
                onRetry?(retryCount, error)
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
}
