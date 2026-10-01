import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    @State private var searchText = ""

    private var hasError: Bool {
        viewModel.errorMessage != nil
    }

    var body: some View {
        HistoryListView(
            conversions: viewModel.conversions,
            searchText: searchText,
            onResetSearch: { searchText = "" },
            onDelete: { id in await viewModel.deleteConversion(id: id) }
        )
        .navigationTitle("История")
        .overlay { loadingOverlay }
        .alert("Ошибка", isPresented: Binding(
            get: { hasError },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .searchable(text: $searchText, prompt: "Поиск по валютам")
        .task {
            await viewModel.loadHistory()
        }
    }

    private var loadingOverlay: some View {
        Group {
            if viewModel.isDeleting || viewModel.isLoading {
                ScreenLoadingOverlayView(title: viewModel.isDeleting ? "Удаление..." : "Загрузка истории...")
            }
        }
    }
}
