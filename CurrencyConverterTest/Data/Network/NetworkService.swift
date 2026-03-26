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

final class NetworkService: Sendable {

    private let session: URLSession
    private let timeout: TimeInterval

    init(timeout: TimeInterval = ConfigurationDefaults.networkTimeout) {
        self.timeout = timeout
        let config = URLSessionConfiguration.default

        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: ConfigurationDefaults.urlCacheMemoryCapacity,
            diskCapacity: ConfigurationDefaults.urlCacheDiskCapacity,
            directory: nil
        )

        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * ConfigurationDefaults.networkResourceTimeoutMultiplier
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)
    }

    init(session: URLSession) {
        self.session = session
        self.timeout = ConfigurationDefaults.networkTimeout
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
