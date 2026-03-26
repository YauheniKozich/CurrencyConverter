//
//  HistoryListView.swift
//  CurrencyConverterTest
//
//  Created by Codex on 26.03.26.
//

import SwiftUI
import SwiftData

struct HistoryListView: View {
    private enum UI {
        static let rowSpacing: CGFloat = 4
        static let minRowHeight: CGFloat = 44
    }

    let searchText: String
    let onResetSearch: (() -> Void)?
    let onDelete: @Sendable (UUID) async -> Void
    private let formatter: any ConversionFormatting

    @Query private var conversions: [Conversion]

    init(
        searchText: String,
        onResetSearch: (() -> Void)? = nil,
        onDelete: @escaping @Sendable (UUID) async -> Void,
        formatter: any ConversionFormatting = ConversionPresentationFormatter(
            numberFormatter: NumberFormatterService(locale: .current)
        )
    ) {
        self.searchText = searchText
        self.onResetSearch = onResetSearch
        self.onDelete = onDelete
        self.formatter = formatter

        let normalizedSearchText = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if normalizedSearchText.isEmpty {
            _conversions = Query(sort: \Conversion.date, order: .reverse)
        } else {
            let predicate = #Predicate<Conversion> { conversion in
                conversion.from.contains(normalizedSearchText) || conversion.to.contains(normalizedSearchText)
            }

            _conversions = Query(filter: predicate, sort: \Conversion.date, order: .reverse)
        }
    }

    var body: some View {
        Group {
            if conversions.isEmpty {
                emptyState
            } else {
                listView
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSearchText = !trimmedSearchText.isEmpty

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
            ForEach(conversions) { item in
                conversionRow(item: item)
            }
            .onDelete { offsets in
                let ids = offsets.map { conversions[$0].id }

                Task {
                    for id in ids {
                        await onDelete(id)
                    }
                }
            }
        }
    }

    private func conversionRow(item: Conversion) -> some View {
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
