import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HistoryViewModel
    var onSelect: ((ConversionHistoryEntry) -> Void)? = nil
    @State private var searchText = ""

    private var hasError: Bool {
        viewModel.errorMessage != nil
    }

    var body: some View {
        HistoryListView(
            conversions: viewModel.conversions,
            searchText: searchText,
            onResetSearch: { searchText = "" },
            onSelect: { entry in
                onSelect?(entry)
                dismiss()
            },
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
        .toolbar {
            if !viewModel.conversions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(
                        item: viewModel.csvExport,
                        preview: SharePreview("История конвертаций", image: Image(systemName: "tablecells"))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Экспорт истории в CSV")
                    .accessibilityIdentifier("history.export.csv")
                    .accessibilityHint("Позволяет сохранить или отправить файл истории конвертаций")
                }
            }
        }
        .task {
            await viewModel.loadHistory()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.conversions.count)
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { oldValue, newValue in
            newValue != nil && oldValue != newValue
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
