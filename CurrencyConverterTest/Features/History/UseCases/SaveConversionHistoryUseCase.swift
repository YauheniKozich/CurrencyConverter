//
//  SaveConversionHistoryUseCase.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 13.03.26.
//

import Foundation
import SwiftData

actor SaveConversionHistoryUseCase: SaveConversionHistoryUseCaseProtocol {

    private let historyActor: any ConversionHistoryStore

    init(historyActor: any ConversionHistoryStore) {
        self.historyActor = historyActor
    }

    func execute(from: String, to: String, amount: Double, result: Double, rate: Double) async throws {
        try await historyActor.saveConversion(
            from: from,
            to: to,
            amount: amount,
            result: result,
            rate: rate
        )
    }
}
