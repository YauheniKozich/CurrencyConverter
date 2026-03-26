//
//  CurrencyConversionUseCaseProtocol.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

protocol CurrencyConversionUseCaseProtocol: Sendable {
    func execute(from: String, to: String, amount: Double) async throws -> ConversionResult
}
