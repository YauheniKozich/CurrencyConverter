//
//  CurrencyConversionUseCase.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 13.03.26.
//

import Foundation

final class CurrencyConversionUseCase: CurrencyConversionUseCaseProtocol {

    private let repository: any CurrencyRepository

    init(repository: any CurrencyRepository) {
        self.repository = repository
    }

    func execute(from: String, to: String, amount: Double) async throws -> ConversionResult {
        guard !from.isEmpty, !to.isEmpty else {
            throw AppError.validationError(message: String(localized: "Не указаны валюты для конвертации"))
        }

        guard amount >= 0, amount.isFinite else {
            throw AppError.validationError(message: String(localized: "Некорректная сумма"))
        }

        try Task.checkCancellation()
        if from == to {
            return ConversionResult(result: amount, rate: 1, isStaleRate: false)
        }
        let conversion = try await repository.convert(from: from, to: to, amount: amount)
        try Task.checkCancellation()
        guard conversion.result.isFinite,
              conversion.rate.isFinite,
              conversion.rate > 0 else {
            throw AppError.validationError(message: String(localized: "Некорректная сумма"))
        }
        return conversion
    }
}
