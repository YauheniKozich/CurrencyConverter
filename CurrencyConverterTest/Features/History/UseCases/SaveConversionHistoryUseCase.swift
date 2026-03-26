//
//  SaveConversionHistoryUseCase.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 13.03.26.
//

import Foundation
import SwiftData

protocol ConversionHistoryActorType: Sendable {
    func saveConversion(from: String, to: String, amount: Double, result: Double, rate: Double) async throws
    func deleteConversion(id: UUID) async throws
}

actor SaveConversionHistoryUseCase: SaveConversionHistoryUseCaseProtocol {

    private let historyActor: any ConversionHistoryActorType

    init(historyActor: any ConversionHistoryActorType) {
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
