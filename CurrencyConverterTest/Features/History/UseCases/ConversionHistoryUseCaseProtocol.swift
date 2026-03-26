//
//  ConversionHistoryUseCaseProtocol.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

protocol ConversionHistoryUseCaseProtocol: Sendable {
    func fetchHistory() async throws -> [Conversion]
    func deleteConversion(id: UUID) async throws
}
