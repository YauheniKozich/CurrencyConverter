//
//  HistoryViewModel.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import Foundation
import SwiftData

@Observable
@MainActor
final class HistoryViewModel {

    private let historyActor: any ConversionHistoryActorType

    private(set) var isDeleting: Bool = false
    private(set) var errorMessage: String?

    init(modelContainer: ModelContainer) throws {
        self.historyActor = try ConversionHistoryActor(modelContainer: modelContainer)
    }

    func deleteConversion(id: UUID) async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await historyActor.deleteConversion(id: id)
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось удалить запись"
            Logger.log("Delete conversion error: \(error)", level: .error)
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
