//
//  LoadCurrenciesUseCase.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 13.03.26.
//

import Foundation

final class LoadCurrenciesUseCase: LoadCurrenciesUseCaseProtocol {

    private let repository: any CurrencyRepository

    init(repository: any CurrencyRepository) {
        self.repository = repository
    }

    func execute(forceRefresh: Bool = false) async throws -> [String] {
        let currencyMap: [String: Currency]

        if forceRefresh {
            currencyMap = try await repository.refreshSupportedCurrencies()
        } else {
            currencyMap = try await repository.fetchSupportedCurrencies()
        }

        return currencyMap.values
            .map { $0.code }
            .sorted()
    }
}
