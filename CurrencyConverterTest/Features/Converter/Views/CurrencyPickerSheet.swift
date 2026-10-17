//
//  CurrencyPickerSheet.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import SwiftUI

struct CurrencyPickerSheet: View {
    let title: String
    @Binding var selectedCurrency: String
    let availableCurrencies: [String]
    let preferences: any UserPreferencesProtocol
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var favoriteCodes: [String]

    init(
        title: String,
        selectedCurrency: Binding<String>,
        availableCurrencies: [String],
        preferences: any UserPreferencesProtocol = UserPreferences()
    ) {
        self.title = title
        self._selectedCurrency = selectedCurrency
        self.availableCurrencies = availableCurrencies
        self.preferences = preferences
        self._favoriteCodes = State(initialValue: preferences.favoriteCurrencies)
    }

    private var allItems: [CurrencyItem] {
        availableCurrencies.map { CurrencyItem(code: $0) }
    }

    private var filteredItems: [CurrencyItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return allItems
        }
        return allItems.filter { item in
            item.code.lowercased().contains(query) ||
            item.name.lowercased().contains(query)
        }
    }

    private var favoriteItems: [CurrencyItem] {
        favoriteCodes.compactMap { code in
            allItems.first { $0.code == code }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    if !favoriteItems.isEmpty {
                        Section("Избранные валюты") {
                            ForEach(favoriteItems) { item in
                                currencyRow(item)
                            }
                        }
                    }

                    Section("Все валюты") {
                        ForEach(allItems) { item in
                            currencyRow(item)
                        }
                    }
                } else {
                    Section {
                        ForEach(filteredItems) { item in
                            currencyRow(item)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Поиск по коду или названию")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if filteredItems.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: favoriteCodes.count)
        }
    }

    private func toggleFavorite(_ code: String) {
        preferences.toggleFavorite(currency: code)
        favoriteCodes = preferences.favoriteCurrencies
    }

    @ViewBuilder
    private func currencyRow(_ item: CurrencyItem) -> some View {
        let isSelected = item.code == selectedCurrency
        let isFav = favoriteCodes.contains(item.code)

        HStack(spacing: 12) {
            Button {
                selectedCurrency = item.code
                dismiss()
            } label: {
                HStack(spacing: 14) {
                    Text(item.flag)
                        .font(.title2)
                        .frame(width: 36, alignment: .center)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.code)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(item.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                            .fontWeight(.semibold)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.code), \(item.name)")
            .accessibilityValue(isSelected ? "Выбрано" : "")
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])

            Button {
                toggleFavorite(item.code)
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .foregroundColor(isFav ? .yellow : .secondary.opacity(0.35))
                    .font(.body)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFav ? "Удалить из избранного" : "Добавить в избранное")
            .accessibilityHint("Переключает статус избранной валюты")
        }
        .swipeActions(edge: .leading) {
            Button {
                toggleFavorite(item.code)
            } label: {
                Label(
                    isFav ? "Удалить из избранного" : "В избранное",
                    systemImage: isFav ? "star.slash" : "star"
                )
            }
            .tint(isFav ? .gray : .yellow)
        }
    }
}

#Preview {
    CurrencyPickerSheet(
        title: "Из валюты",
        selectedCurrency: .constant("USD"),
        availableCurrencies: ["USD", "EUR", "GBP", "JPY", "CHF", "RUB", "CAD", "AUD"]
    )
}
