//
//  HistoryView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel?
    @State private var searchText = ""
    @Environment(\.modelContext) private var modelContext

    private var hasError: Bool {
        viewModel?.errorMessage != nil
    }

    private func ensureViewModel() {
        guard viewModel == nil else { return }
        do {
            viewModel = try HistoryViewModel(modelContainer: modelContext.container)
        } catch {
            Logger.log("Failed to create HistoryViewModel: \(error)", level: .error)
        }
    }

    var body: some View {
        HistoryListView(
            searchText: searchText,
            onResetSearch: {
                searchText = ""
            },
            onDelete: { id in
                await deleteConversion(id: id)
            }
        )
            .navigationTitle("История")
            .overlay { loadingOverlay }
            .alert("Ошибка", isPresented: Binding(
                get: { hasError },
                set: { isPresented in
                    if !isPresented {
                        viewModel?.clearError()
                    }
                }
            )) {
                Button("OK") {
                    viewModel?.clearError()
                }
            } message: {
                Text(viewModel?.errorMessage ?? "")
            }
            .searchable(text: $searchText, prompt: "Поиск по валютам")
            .onAppear(perform: ensureViewModel)
    }

    private var loadingOverlay: some View {
        Group {
            if let vm = viewModel, vm.isDeleting {
                ScreenLoadingOverlayView(title: "Удаление...")
            }
        }
    }

    @MainActor
    private func deleteConversion(id: UUID) async {
        await viewModel?.deleteConversion(id: id)
    }
}
