//
//  HistoryViewModel.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation

@Observable
@MainActor
final class HistoryViewModel {

    private let historyUseCase: any ConversionHistoryUseCaseProtocol

    private(set) var conversions: [ConversionHistoryEntry] = []
    private(set) var isLoading = false
    private(set) var isDeleting: Bool = false
    private(set) var errorMessage: String?

    init(historyUseCase: any ConversionHistoryUseCaseProtocol) {
        self.historyUseCase = historyUseCase
    }

    func loadHistory() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedConversions = try await historyUseCase.fetchHistory()
            guard !Task.isCancelled else { return }
            conversions = loadedConversions
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Не удалось загрузить историю"
            Logger.log("Load conversion history error: \(error)", level: .error)
        }
    }

    func deleteConversion(id: UUID) async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await historyUseCase.deleteConversion(id: id)
            let loadedConversions = try await historyUseCase.fetchHistory()
            guard !Task.isCancelled else { return }
            conversions = loadedConversions
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Не удалось удалить запись"
            Logger.log("Delete conversion error: \(error)", level: .error)
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
