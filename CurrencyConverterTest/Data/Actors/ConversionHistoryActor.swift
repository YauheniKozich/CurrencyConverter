//
//  ConversionHistoryActor.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 13.03.26.
//

import Foundation
import SwiftData

protocol ConversionHistoryActorProtocol {
    func saveConversion(from: String, to: String, amount: Double, result: Double, rate: Double) async throws
    func deleteConversion(id: UUID) async throws
}

actor ConversionHistoryActor: ConversionHistoryActorProtocol {

    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) throws {
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = false
    }

    func saveConversion(from: String, to: String, amount: Double, result: Double, rate: Double) async throws {
        let conversion = Conversion(
            from: from,
            to: to,
            amount: amount,
            result: result,
            rate: rate
        )
        modelContext.insert(conversion)
        try modelContext.save()
    }

    func deleteConversion(id: UUID) async throws {
        let descriptor = FetchDescriptor<Conversion>(
            predicate: #Predicate { $0.id == id }
        )
        if let conversion = try modelContext.fetch(descriptor).first {
            modelContext.delete(conversion)
            try modelContext.save()
        }
    }
}
