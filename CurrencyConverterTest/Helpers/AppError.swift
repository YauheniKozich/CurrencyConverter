//
//  AppError.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import Foundation

/// Перечисление основных ошибок приложения
enum AppError: LocalizedError {
    case configurationError(String)
    case networkError(Error)
    case decodingError(Error)
    case dataError(String)
    case validationError(String)
    case repositoryError(String)

    var errorDescription: String? {
        switch self {
        case .configurationError(let message):
            return "Ошибка конфигурации: \(message)"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Ошибка обработки данных: \(error.localizedDescription)"
        case .dataError(let message):
            return "Ошибка данных: \(message)"
        case .validationError(let message):
            return "Ошибка валидации: \(message)"
        case .repositoryError(let message):
            return "Ошибка репозитория: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .configurationError:
            return "Проверьте настройки приложения"
        case .networkError:
            return "Проверьте подключение к интернету и повторите попытку"
        case .decodingError:
            return "Данные получены в неверном формате"
        case .dataError:
            return "Проверьте корректность введенных данных"
        case .validationError:
            return "Проверьте корректность введенных данных"
        case .repositoryError:
            return "Попробуйте позже или обратитесь в поддержку"
        }
    }
}

/// Протокол для обработки ошибок
protocol ErrorHandling {
    func handleError(_ error: Error) -> AppError
}

/// Реализация обработчика ошибок
final class ErrorHandler: ErrorHandling {
    func handleError(_ error: Error) -> AppError {
        switch error {
        case let appError as AppError:
            return appError
        case let decodingError as DecodingError:
            return .decodingError(decodingError)
        case let urlError as URLError:
            return .networkError(urlError)
        case let nsError as NSError:
            if nsError.domain == "CurrencyAPI" {
                return .dataError(nsError.localizedDescription)
            }
            return .repositoryError(nsError.localizedDescription)
        default:
            return .repositoryError(error.localizedDescription)
        }
    }
}
