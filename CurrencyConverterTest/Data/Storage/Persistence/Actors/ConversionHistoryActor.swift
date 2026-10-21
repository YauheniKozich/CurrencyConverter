//
//  ConversionHistoryActor.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 13.03.26.
//

import Foundation
import SwiftData

actor ConversionHistoryActor: ModelActor, ConversionHistoryStore, ConversionHistoryReader {

    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    private let maxEntries: Int

    init(
        modelContainer: ModelContainer,
        maxEntries: Int = ConfigurationDefaults.maxHistoryEntries
    ) throws {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.maxEntries = maxEntries
    }

    func saveConversion(from: String, to: String, amount: Double, result: Double, rate: Double) async throws {
        let conversion = Conversion(
            from: from,
            to: to,
            amount: amount,
            result: result,
            rate: rate
        )
        try Task.checkCancellation()
        do {
            modelContext.insert(conversion)
            try trimHistoryIfNeeded()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func deleteConversion(id: UUID) async throws {
        let descriptor = FetchDescriptor<Conversion>(
            predicate: #Predicate { $0.id == id }
        )
        if let conversion = try modelContext.fetch(descriptor).first {
            try Task.checkCancellation()
            modelContext.delete(conversion)
            try saveOrRollback()
        }
    }

    func clearAllHistory() async throws {
        let descriptor = FetchDescriptor<Conversion>()
        let all = try modelContext.fetch(descriptor)
        for entry in all {
            modelContext.delete(entry)
        }
        try saveOrRollback()
    }

    func fetchHistory() async throws -> [ConversionHistoryEntry] {
        let descriptor = FetchDescriptor<Conversion>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map {
            ConversionHistoryEntry(
                id: $0.id,
                from: $0.from,
                to: $0.to,
                amount: $0.amount,
                result: $0.result,
                rate: $0.rate,
                date: $0.date
            )
        }
    }

    // MARK: - Private Helpers

    private func saveOrRollback() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func trimHistoryIfNeeded() throws {
        guard maxEntries > 0 else { return }

        let descriptor = FetchDescriptor<Conversion>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)
        if all.count > maxEntries {
            for entry in all.dropFirst(maxEntries) {
                modelContext.delete(entry)
            }
        }
    }
}
