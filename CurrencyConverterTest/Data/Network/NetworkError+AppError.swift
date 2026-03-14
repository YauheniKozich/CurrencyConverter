//
//  NetworkError+AppError.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 14.03.26.
//

import Foundation

// MARK: - NetworkError to AppError Mapping

extension NetworkError {
    
    /// Маппит NetworkError на AppError с сохранением контекста
    var appError: AppError {
        switch self {
        case .invalidURL:
            return .validationError(message: "Неверный URL адрес")
        case .invalidResponse:
            return .serverError(statusCode: 0)
        case .statusCodeError(let code):
            return .serverError(statusCode: code)
        case .decodingError(let reason):
            return .invalidDataFormat(reason: reason)
        case .networkUnavailable(let error):
            if let urlError = error as? URLError {
                return urlError.appError
            }
            return .networkUnavailable
        }
    }
}

extension URLError {
    
    /// Маппит URLError на AppError
    var appError: AppError {
        switch code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkUnavailable
        case .timedOut:
            return .networkTimeout
        case .badURL, .unsupportedURL:
            return .validationError(message: "Неверный URL адрес")
        case .cannotFindHost, .cannotConnectToHost:
            return .networkUnavailable
        default:
            return .networkUnavailable
        }
    }
}
