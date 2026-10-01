import Foundation

protocol ConversionHistoryStore: Sendable {
    func saveConversion(from: String, to: String, amount: Double, result: Double, rate: Double) async throws
    func deleteConversion(id: UUID) async throws
}

protocol ConversionHistoryReader: Sendable {
    func fetchHistory() async throws -> [ConversionHistoryEntry]
}

typealias ConversionHistoryActorType = ConversionHistoryStore
