//
//  ConversionService.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

/// Сервис для выполнения конвертации валют
@MainActor
final class ConversionService {

    private let conversionUseCase: any CurrencyConversionUseCaseProtocol
    private let saveConversionHistoryUseCase: any SaveConversionHistoryUseCaseProtocol
    private let numberFormatter: any NumberFormatting

    init(
        conversionUseCase: any CurrencyConversionUseCaseProtocol,
        saveConversionHistoryUseCase: any SaveConversionHistoryUseCaseProtocol,
        numberFormatter: any NumberFormatting
    ) {
        self.conversionUseCase = conversionUseCase
        self.saveConversionHistoryUseCase = saveConversionHistoryUseCase
        self.numberFormatter = numberFormatter
    }

    func convert(
        from: String,
        to: String,
        amount: String
    ) async throws -> ConversionResult {
        guard let amountValue = numberFormatter.parse(amount) else {
            throw ConversionError.invalidAmount
        }

        let conversion = try await conversionUseCase.execute(
            from: from,
            to: to,
            amount: amountValue
        )

        try Task.checkCancellation()

        do {
            try await saveConversionHistoryUseCase.execute(
                from: from,
                to: to,
                amount: amountValue,
                result: conversion.result,
                rate: conversion.rate
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Logger.log("Failed to save conversion history: \(error)", level: .error)
        }

        return conversion
    }

    enum ConversionError: LocalizedError {
        case invalidAmount

        var errorDescription: String? {
            switch self {
            case .invalidAmount:
                return "Неверный формат суммы"
            }
        }
    }
}
