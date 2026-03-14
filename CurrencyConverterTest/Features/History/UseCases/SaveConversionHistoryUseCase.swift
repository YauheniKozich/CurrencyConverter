//
//  SaveConversionHistoryUseCase.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 13.03.26.
//

import Foundation

final class SaveConversionHistoryUseCase {

    private let historyActor: ConversionHistoryActorProtocol

    init(historyActor: ConversionHistoryActorProtocol) {
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
