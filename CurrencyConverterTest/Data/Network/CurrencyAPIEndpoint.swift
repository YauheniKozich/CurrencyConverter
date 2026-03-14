//
//  CurrencyAPIEndpoint.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

// MARK: - API Endpoint

/// Представление API эндпоинта для запросов к Currency API
struct CurrencyAPIEndpoint: Sendable {

    private let baseURL: URL
    private let path: String
    private let queryItems: [URLQueryItem]
    private let apiKey: String?

    init(baseURL: URL, path: String, queryItems: [URLQueryItem] = [], apiKey: String? = nil) {
        self.baseURL = baseURL
        self.path = path
        self.queryItems = queryItems
        self.apiKey = apiKey
    }

    /// Создаёт эндпоинт для получения списка валют
    static func currencies(apiKey: String, baseURL: URL) -> CurrencyAPIEndpoint {
        CurrencyAPIEndpoint(
            baseURL: baseURL,
            path: "v3/currencies",
            queryItems: [],
            apiKey: apiKey
        )
    }

    /// Создаёт эндпоинт для конвертации валют
    static func convert(from: String, to: String, apiKey: String, baseURL: URL) -> CurrencyAPIEndpoint {
        CurrencyAPIEndpoint(
            baseURL: baseURL,
            path: "v3/latest",
            queryItems: [
                URLQueryItem(name: "base_currency", value: from),
                URLQueryItem(name: "currencies", value: to)
            ],
            apiKey: apiKey
        )
    }

    /// Создаёт URLRequest из эндпоинта
    func makeURLRequest() throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let combinedPath = [basePath, endpointPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = "/" + combinedPath

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
        }

        return request
    }
}
