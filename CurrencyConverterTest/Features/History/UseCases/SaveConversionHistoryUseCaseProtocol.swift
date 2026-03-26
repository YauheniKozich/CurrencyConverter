//
//  SaveConversionHistoryUseCaseProtocol.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

protocol SaveConversionHistoryUseCaseProtocol {
    @MainActor func execute(from: String, to: String, amount: Double, result: Double, rate: Double) async throws
}
