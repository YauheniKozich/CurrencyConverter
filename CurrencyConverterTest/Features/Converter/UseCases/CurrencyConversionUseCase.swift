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
            throw AppError.validationError(message: "Не указаны валюты для конвертации")
        }

        guard amount >= 0, !amount.isNaN else {
            throw AppError.validationError(message: "Некорректная сумма")
        }

        return try await repository.convert(from: from, to: to, amount: amount)
    }
}
