//
//  CurrencyEntity.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import AppIntents

struct CurrencyEntity: AppEntity {
    static let defaultQuery = CurrencyEntityQuery()
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Валюта"

    let id: String
    let name: String

    private var displayName: String {
        guard name.isEmpty else { return name }
        return Locale.current.localizedString(forCurrencyCode: id.uppercased()) ?? id.uppercased()
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(id)",
            subtitle: "\(displayName)"
        )
    }

    init(id: String, name: String = "") {
        self.id = id
        self.name = name
    }
}

struct CurrencyEntityQuery: EntityStringQuery {
    static let popularCurrencies: [CurrencyEntity] = [
        CurrencyEntity(id: "USD"),
        CurrencyEntity(id: "EUR"),
        CurrencyEntity(id: "RUB"),
        CurrencyEntity(id: "BYN"),
        CurrencyEntity(id: "GBP"),
        CurrencyEntity(id: "JPY"),
        CurrencyEntity(id: "CNY"),
        CurrencyEntity(id: "CHF"),
        CurrencyEntity(id: "CAD"),
        CurrencyEntity(id: "AUD"),
        CurrencyEntity(id: "PLN"),
        CurrencyEntity(id: "TRY"),
        CurrencyEntity(id: "KZT"),
        CurrencyEntity(id: "AED")
    ]

    private let loadCurrencies: @Sendable () async throws -> [String: Currency]

    init() {
        self.init(loadCurrencies: Self.loadAvailableCurrencies)
    }

    init(loadCurrencies: @escaping @Sendable () async throws -> [String: Currency]) {
        self.loadCurrencies = loadCurrencies
    }

    private static func loadAvailableCurrencies() async throws -> [String: Currency] {
        // Reuse the app repository's RAM/disk/offline policy, not a second currency list.
        let repository = try await AppDependencies.shared.createRepository()
        return try await repository.fetchSupportedCurrencies()
    }

    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        guard !identifiers.isEmpty else { return [] }
        try Task.checkCancellation()
        let currencies = try await loadCurrencies()
        try Task.checkCancellation()
        return identifiers.compactMap { identifier in
            let code = identifier.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard let currency = currencies[code] else { return nil }
            return CurrencyEntity(id: currency.code)
        }
    }

    func entities(matching string: String) async throws -> [CurrencyEntity] {
        try Task.checkCancellation()
        let currencies = try await loadCurrencies()
        try Task.checkCancellation()
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return currencies.values.filter { currency in
            query.isEmpty || currency.code.localizedCaseInsensitiveContains(query)
                || currency.name.localizedCaseInsensitiveContains(query)
                || CurrencyItem(code: currency.code).name.localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.code < $1.code }
        .map { CurrencyEntity(id: $0.code) }
    }

    func suggestedEntities() async throws -> [CurrencyEntity] {
        try Task.checkCancellation()
        let currencies = try await loadCurrencies()
        try Task.checkCancellation()
        return Self.popularCurrencies.filter { currencies[$0.id] != nil }
    }
}
