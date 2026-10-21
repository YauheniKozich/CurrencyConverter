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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
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
        availableCurrencies.map {
            CurrencyItem(code: $0, customName: locale.localizedString(forCurrencyCode: $0))
        }
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

        HStack(alignment: .top, spacing: 12) {
            Button {
                selectedCurrency = item.code
                dismiss()
            } label: {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.code)
                            .font(.headline)
                            .fixedSize()
                        Text(item.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                } else {
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
                            .fixedSize(horizontal: false, vertical: true)
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
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
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
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFav ? "Удалить из избранного" : "Добавить в избранное")
            .accessibilityHint("Переключает статус избранной валюты")
            .accessibilityValue(item.code)
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
        title: String(localized: "Из валюты"),
        selectedCurrency: .constant("USD"),
        availableCurrencies: ["USD", "EUR", "GBP", "JPY", "CHF", "RUB", "CAD", "AUD"]
    )
}

#Preview("English Narrow") {
    CurrencyPickerSheet(
        title: "From currency",
        selectedCurrency: .constant("USD"),
        availableCurrencies: ["USD", "EUR", "SGD", "NOK"]
    )
    .environment(\.locale, Locale(identifier: "en"))
    .frame(width: 320)
}

#Preview("Russian Narrow") {
    CurrencyPickerSheet(
        title: "Из валюты",
        selectedCurrency: .constant("USD"),
        availableCurrencies: ["USD", "EUR", "SGD", "NOK"]
    )
    .environment(\.locale, Locale(identifier: "ru"))
    .frame(width: 320)
}
