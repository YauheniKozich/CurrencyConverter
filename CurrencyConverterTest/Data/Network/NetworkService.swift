//
//  NetworkService.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - API Error Response DTO

struct CurrencyAPIErrorDTO: Decodable, Sendable {
    let message: String?
    let errors: [String: [String]]?
}

// MARK: - Network Error

enum NetworkError: Error, Sendable {
    case invalidResponse
    case invalidURL
    case statusCodeError(Int)
    case apiError(statusCode: Int, message: String)
    case decodingError(String)
    case networkUnavailable(any Error)
}

// MARK: - Network Service

final class NetworkService: Sendable {

    private let session: URLSession
    private let timeout: TimeInterval

    init(timeout: TimeInterval = ConfigurationDefaults.networkTimeout) {
        self.timeout = timeout
        let config = URLSessionConfiguration.default

        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = URLCache(
            memoryCapacity: ConfigurationDefaults.urlCacheMemoryCapacity,
            diskCapacity: ConfigurationDefaults.urlCacheDiskCapacity,
            directory: nil
        )

        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * ConfigurationDefaults.networkResourceTimeoutMultiplier
        config.waitsForConnectivity = false

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
                if let apiError = try? JSONDecoder().decode(CurrencyAPIErrorDTO.self, from: data) {
                    var detail = apiError.message ?? ""
                    if let fieldErrors = apiError.errors {
                        let combined = fieldErrors.values.flatMap { $0 }.joined(separator: ", ")
                        if !combined.isEmpty {
                            detail = detail.isEmpty ? combined : "\(detail): \(combined)"
                        }
                    }
                    if !detail.isEmpty {
                        throw NetworkError.apiError(statusCode: httpResponse.statusCode, message: detail)
                    }
                }
                throw NetworkError.statusCodeError(httpResponse.statusCode)
            }

            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
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
