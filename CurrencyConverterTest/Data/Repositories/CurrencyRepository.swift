//
//  CurrencyRepository.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

protocol CurrencyRepository {
    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult
    func fetchSupportedCurrencies() async throws -> [String: Currency]
    func refreshSupportedCurrencies() async throws -> [String: Currency]
}
