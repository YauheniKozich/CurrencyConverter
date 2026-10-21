import SwiftUI

struct HistoryListView: View {
    private enum UI {
        static let rowSpacing: CGFloat = 4
        static let minRowHeight: CGFloat = 44
    }

    let conversions: [ConversionHistoryEntry]
    let searchText: String
    let onResetSearch: (() -> Void)?
    let onSelect: ((ConversionHistoryEntry) -> Void)?
    let onDelete: (UUID) async -> Void
    private let formatter: any ConversionFormatting
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        conversions: [ConversionHistoryEntry],
        searchText: String,
        onResetSearch: (() -> Void)? = nil,
        onSelect: ((ConversionHistoryEntry) -> Void)? = nil,
        onDelete: @escaping (UUID) async -> Void,
        formatter: any ConversionFormatting = ConversionPresentationFormatter(
            numberFormatter: NumberFormatterService(locale: .current)
        )
    ) {
        self.conversions = conversions
        self.searchText = searchText
        self.onResetSearch = onResetSearch
        self.onSelect = onSelect
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
                ? Text("Попробуйте изменить запрос поиска")
                : Text("Вы ещё не выполнили ни одной конвертации"),
            actionTitle: hasSearchText && onResetSearch != nil ? "Сбросить поиск" : nil
        ) {
            onResetSearch?()
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredConversions) { item in
                if let onSelect {
                    Button {
                        onSelect(item)
                    } label: {
                        conversionRow(item: item)
                    }
                    .buttonStyle(.plain)
                } else {
                    conversionRow(item: item)
                }
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: UI.rowSpacing) {
                Text("\(formatter.formatAmount(item.amount)) \(item.from) → \(formatter.formatResult(item.result)) \(item.to)")
                    .font(.body.weight(.medium))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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

            if onSelect != nil {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(onSelect != nil ? "Нажмите, чтобы применить эту конвертацию" : "")
        .frame(minHeight: UI.minRowHeight)
    }
}

#Preview("With Items") {
    NavigationStack {
        HistoryListView(
            conversions: [
                ConversionHistoryEntry(from: "USD", to: "EUR", amount: 100, result: 92.5, rate: 0.925),
                ConversionHistoryEntry(from: "EUR", to: "GBP", amount: 50, result: 42.8, rate: 0.856)
            ],
            searchText: "",
            onResetSearch: {},
            onSelect: { _ in },
            onDelete: { _ in }
        )
    }
}

#Preview("Empty State") {
    NavigationStack {
        HistoryListView(
            conversions: [],
            searchText: "",
            onResetSearch: {},
            onDelete: { _ in }
        )
    }
}

#Preview("Accessibility Text Size") {
    NavigationStack {
        HistoryListView(
            conversions: [
                ConversionHistoryEntry(from: "USD", to: "EUR", amount: 1250000, result: 1156250, rate: 0.925)
            ],
            searchText: "",
            onResetSearch: {},
            onSelect: { _ in },
            onDelete: { _ in }
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
