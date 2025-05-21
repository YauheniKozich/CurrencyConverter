//
//  CurrencyRepository.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI

struct ConversionResult {
    let result: Double
    let rate: Double
}

protocol CurrencyRepository {
    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult
    func fetchSupportedCurrencies() async throws -> [String: Currency]
    func saveConversion(_ conversion: Conversion) async
}

extension CurrencyRepository {
    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        throw NSError(domain: "NotImplemented", code: 0, userInfo: [NSLocalizedDescriptionKey: "fetchSupportedCurrencies is not implemented"])
    }
}
