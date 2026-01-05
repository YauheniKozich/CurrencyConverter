//
//  APIEndpoint.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - Network Error

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

// MARK: - Endpoint Currency API

struct CurrencyAPIEndpoint: APIEndpointProtocol {
    
    private let baseURL: URL
    private let path: String
    private let queryItems: [URLQueryItem]
    
    init(baseURL: URL, path: String, queryItems: [URLQueryItem] = []) {
        self.baseURL = baseURL
        self.path = path
        self.queryItems = queryItems
    }
    
    static func currencies(apiKey: String, baseURL: URL) -> CurrencyAPIEndpoint {
        CurrencyAPIEndpoint(
            baseURL: baseURL,
            path: "/v3/currencies",
            queryItems: [URLQueryItem(name: "apikey", value: apiKey)]
        )
    }
    
    static func convert(from: String, to: String, apiKey: String, baseURL: URL) -> CurrencyAPIEndpoint {
        CurrencyAPIEndpoint(
            baseURL: baseURL,
            path: "/v3/latest",
            queryItems: [
                URLQueryItem(name: "base_currency", value: from),
                URLQueryItem(name: "currencies", value: to),
                URLQueryItem(name: "apikey", value: apiKey)
            ]
        )
    }
    
    var urlRequest: URLRequest {
        let urlWithPath = baseURL.appendingPathComponent(path)
        var components = URLComponents(url: urlWithPath, resolvingAgainstBaseURL: false)!
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        
        return request
    }
}

// MARK: - Network Service

final class NetworkService {
    
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    
    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.jsonDecoder = decoder
        
        jsonDecoder.dateDecodingStrategy = .iso8601
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            Logger.log("Не удалось декодировать ответ: \(error)")
            throw NetworkError.decodingError(error)
        }
    }
    
    func request(_ endpoint: APIEndpointProtocol) async throws -> Data {
        let request = endpoint.urlRequest
        
        Logger.log("Запрос: \(request.url?.absoluteString ?? "без URL")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            Logger.log("Статус: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.statusCodeError(httpResponse.statusCode)
            }
            
            return data
        } catch {
            Logger.log("Ошибка запроса: \(error)")
            throw error
        }
    }
    
    func requestWithRetry(
        _ endpoint: APIEndpointProtocol,
        maxRetries: Int = 3,
        retryDelay: Double = 1.0
    ) async throws -> Data {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await request(endpoint)
            } catch {
                lastError = error
                Logger.log("Попытка \(attempt) не удалась: \(error)")
                
                // Если это последняя попытка - выходим
                guard attempt < maxRetries else { break }
                
                // Ждем перед следующей попыткой
                let delay = retryDelay * Double(attempt)
                Logger.log("Ждем \(String(format: "%.1f", delay)) секунд перед следующей попыткой")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // Если дошли сюда - все попытки исчерпаны
        throw lastError ?? NetworkError.unknown
    }
}

// MARK: - Extension Network Service

extension NetworkService {
    
    // Упрощенный запрос с автоматическим декодированием
    func requestDecoded<T: Decodable>(_ endpoint: APIEndpointProtocol) async throws -> T {
        let data = try await request(endpoint)
        return try decode(data)
    }
    
    func requestDecodedWithRetry<T: Decodable>(
        _ endpoint: APIEndpointProtocol,
        maxRetries: Int = 3
    ) async throws -> T {
        let data = try await requestWithRetry(endpoint, maxRetries: maxRetries)
        return try decode(data)
    }
}
