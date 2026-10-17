//
//  APIKeyValidator.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import Foundation

// MARK: - Validation Result

enum APIKeyValidationResult: Sendable, Equatable {
    case valid(remainingQuota: Int?)
    case invalid(message: String)
    case networkError(message: String)
}

// MARK: - Protocol

protocol APIKeyValidating: Sendable {
    func validate(apiKey: String) async -> APIKeyValidationResult
}

// MARK: - Status DTO

struct CurrencyAPIStatusDTO: Decodable, Sendable {
    struct Quotas: Decodable, Sendable {
        struct Month: Decodable, Sendable {
            let total: Int?
            let used: Int?
            let remaining: Int?
        }
        let month: Month?
    }
    let quotas: Quotas?
}

// MARK: - Implementation

final class APIKeyValidator: APIKeyValidating {
    private let networkService: NetworkService
    private let baseURL: URL

    init(
        networkService: NetworkService = NetworkService(timeout: 10),
        baseURL: URL = ConfigurationDefaults.defaultBaseURL
    ) {
        self.networkService = networkService
        self.baseURL = baseURL
    }

    func validate(apiKey: String) async -> APIKeyValidationResult {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .invalid(message: String(localized: "API ключ не может быть пустым"))
        }

        let endpoint = CurrencyAPIEndpoint.status(apiKey: trimmed, baseURL: baseURL)
        do {
            let data = try await networkService.request(endpoint)
            let statusDTO = try? JSONDecoder().decode(CurrencyAPIStatusDTO.self, from: data)
            let remaining = statusDTO?.quotas?.month?.remaining
            return .valid(remainingQuota: remaining)
        } catch let NetworkError.apiError(statusCode, message) where statusCode == 401 {
            return .invalid(message: message.isEmpty ? String(localized: "Неверный API ключ (код 401)") : message)
        } catch let NetworkError.statusCodeError(statusCode) where statusCode == 401 {
            return .invalid(message: String(localized: "Неверный API ключ (код 401)"))
        } catch is CancellationError {
            return .networkError(message: String(localized: "Запрос отменен"))
        } catch {
            return .networkError(message: error.localizedDescription)
        }
    }
}
