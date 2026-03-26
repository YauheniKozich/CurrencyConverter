//
//  LoadCurrenciesUseCaseProtocol.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

protocol LoadCurrenciesUseCaseProtocol: Sendable {
    func execute(forceRefresh: Bool) async throws -> [String]
}
