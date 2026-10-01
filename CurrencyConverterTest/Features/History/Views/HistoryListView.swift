import SwiftUI

struct HistoryListView: View {
    private enum UI {
        static let rowSpacing: CGFloat = 4
        static let minRowHeight: CGFloat = 44
    }

    let conversions: [ConversionHistoryEntry]
    let searchText: String
    let onResetSearch: (() -> Void)?
    let onDelete: (UUID) async -> Void
    private let formatter: any ConversionFormatting

    init(
        conversions: [ConversionHistoryEntry],
        searchText: String,
        onResetSearch: (() -> Void)? = nil,
        onDelete: @escaping (UUID) async -> Void,
        formatter: any ConversionFormatting = ConversionPresentationFormatter(
            numberFormatter: NumberFormatterService(locale: .current)
        )
    ) {
        self.conversions = conversions
        self.searchText = searchText
        self.onResetSearch = onResetSearch
        self.onDelete = onDelete
        self.formatter = formatter
    }

    private var filteredConversions: [ConversionHistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversions }
        return conversions.filter {
            $0.from.localizedCaseInsensitiveContains(query)
                || $0.to.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if filteredConversions.isEmpty {
                emptyState
            } else {
                listView
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let hasSearchText = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        ScreenFeedbackView(
            title: hasSearchText ? "Ничего не найдено" : "Нет истории",
            systemImage: hasSearchText ? "magnifyingglass" : "clock.badge.exclamationmark",
            description: hasSearchText
                ? "Попробуйте изменить запрос поиска"
                : "Вы ещё не выполнили ни одной конвертации",
            actionTitle: hasSearchText && onResetSearch != nil ? "Сбросить поиск" : nil
        ) {
            onResetSearch?()
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredConversions) { item in
                conversionRow(item: item)
            }
            .onDelete { offsets in
                let visibleConversions = filteredConversions
                let ids = offsets.map { visibleConversions[$0].id }
                Task {
                    for id in ids {
                        await onDelete(id)
                    }
                }
            }
        }
    }

    private func conversionRow(item: ConversionHistoryEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: UI.rowSpacing) {
                Text("\(formatter.formatAmount(item.amount)) \(item.from) → \(formatter.formatResult(item.result)) \(item.to)")
                    .font(.body)
                    .lineLimit(2)
                    .accessibilityLabel("\(formatter.formatAmount(item.amount)) \(item.from) в \(formatter.formatResult(item.result)) \(item.to)")

                Text("Курс: \(formatter.formatRate(item.rate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Курс обмена: \(formatter.formatRate(item.rate))")

                Text(item.date, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Дата конвертации: \(item.date.formatted(date: .complete, time: .shortened))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .frame(minHeight: UI.minRowHeight)
    }
}
