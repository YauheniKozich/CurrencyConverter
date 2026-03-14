//
//  HistoryView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Conversion.date, order: .reverse) private var allConversions: [Conversion]
    @State private var searchText = ""

    var filtered: [Conversion] {
        if searchText.isEmpty { return allConversions }
        return allConversions.filter { "\($0.from)/\($0.to)".localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if allConversions.isEmpty {
                ContentUnavailableView(
                    "Нет истории",
                    systemImage: "clock.badge.exclamationmark",
                    description: Text("Вы ещё не выполнили ни одной конвертации")
                )
            } else {
                List {
                    ForEach(filtered) { item in
                        VStack(alignment: .leading) {
                            Text(String(format: "%.2f %@ → %.2f %@", item.amount, item.from, item.result, item.to))
                                .font(.body)
                            Text(String(format: "Курс: %.4f", item.rate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Дата: \(item.date.formatted())")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete(perform: deleteConversions)
                }
                .refreshable {
                    await refresh()
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("История")
    }

    private func refresh() async {
        // Небольшая задержка для визуального эффекта refresh
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    private func deleteConversions(at offsets: IndexSet) {
        let modelContext = allConversions.first?.modelContext
        guard let modelContext = modelContext else { return }

        for index in offsets {
            let conversion = filtered[index]
            modelContext.delete(conversion)
        }

        try? modelContext.save()
    }
}
