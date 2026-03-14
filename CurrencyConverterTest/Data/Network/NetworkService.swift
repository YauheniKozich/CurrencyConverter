//
//  NetworkService.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - Network Error

enum NetworkError: Error, Sendable {
    case invalidResponse
    case invalidURL
    case statusCodeError(Int)
    case decodingError(String)
    case networkUnavailable(Error)
}

// MARK: - Network Service

final class NetworkService {

    private let session: URLSession

    init(timeout: TimeInterval = 30.0) {
        let config = URLSessionConfiguration.default
        
        // HTTP кэширование
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,  // 10 MB
            diskCapacity: 50 * 1024 * 1024,    // 50 MB
            directory: nil
        )
        
        // Таймауты
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config)
    }

    init(session: URLSession) {
        self.session = session
    }

    func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            let decoder = makeDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger.log("Failed to decode response: \(error)", level: .error)
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    func request(_ endpoint: CurrencyAPIEndpoint) async throws -> Data {
        let request = try endpoint.makeURLRequest()

        Logger.log("Request: \(request.url?.absoluteString ?? "no URL")", level: .debug)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            // Логгирование статуса и кэша
            Logger.log("Status: \(httpResponse.statusCode)", level: .debug)
            
            if let age = httpResponse.value(forHTTPHeaderField: "Age") {
                Logger.log("Cache: hit (age: \(age)s)", level: .debug)
            } else {
                Logger.log("Cache: miss", level: .debug)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.statusCodeError(httpResponse.statusCode)
            }

            return data
        } catch let error as NetworkError {
            Logger.log("Request error: \(error.localizedDescription)", level: .error)
            throw error
        } catch {
            Logger.log("Request error: \(error.localizedDescription)", level: .error)
            throw NetworkError.networkUnavailable(error)
        }
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
