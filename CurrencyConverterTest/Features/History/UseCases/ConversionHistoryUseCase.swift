import Foundation

struct ConversionHistoryUseCase: ConversionHistoryUseCaseProtocol {
    private let historyReader: any ConversionHistoryReader
    private let historyStore: any ConversionHistoryStore

    init(historyActor: any ConversionHistoryStore & ConversionHistoryReader) {
        self.historyReader = historyActor
        self.historyStore = historyActor
    }

    func fetchHistory() async throws -> [ConversionHistoryEntry] {
        try await historyReader.fetchHistory()
    }

    func deleteConversion(id: UUID) async throws {
        try await historyStore.deleteConversion(id: id)
    }
}
