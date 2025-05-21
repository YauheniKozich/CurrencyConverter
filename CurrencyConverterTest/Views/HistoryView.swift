//
//  HistoryView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 21.05.25.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query private var allConversions: [Conversion]
    @State private var searchText = ""
    
    var filtered: [Conversion] {
        if searchText.isEmpty { return allConversions }
        return allConversions.filter { "\($0.from)/\($0.to)".localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List(filtered) { item in
            VStack(alignment: .leading) {
                Text(String(format: "%.2f %@ → %.2f %@", item.amount, item.from, item.result, item.to))
                Text(String(format: "Курс: %.2f", item.rate)).font(.caption)
                Text("Дата: \(item.date.formatted())").font(.caption2).foregroundColor(.gray)
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("История")
    }
}
