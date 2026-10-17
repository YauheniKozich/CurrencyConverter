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

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(id)",
            subtitle: "\(name)"
        )
    }

    init(id: String, name: String = "") {
        self.id = id
        self.name = name
    }
}

struct CurrencyEntityQuery: EntityQuery {
    static let popularCurrencies: [CurrencyEntity] = [
        CurrencyEntity(id: "USD", name: "Доллар США"),
        CurrencyEntity(id: "EUR", name: "Евро"),
        CurrencyEntity(id: "RUB", name: "Российский рубль"),
        CurrencyEntity(id: "BYN", name: "Белорусский рубль"),
        CurrencyEntity(id: "GBP", name: "Британский фунт"),
        CurrencyEntity(id: "JPY", name: "Японская иена"),
        CurrencyEntity(id: "CNY", name: "Китайский юань"),
        CurrencyEntity(id: "CHF", name: "Швейцарский франк"),
        CurrencyEntity(id: "CAD", name: "Канадский доллар"),
        CurrencyEntity(id: "AUD", name: "Австралийский доллар"),
        CurrencyEntity(id: "PLN", name: "Польский злотый"),
        CurrencyEntity(id: "TRY", name: "Турецкая лира"),
        CurrencyEntity(id: "KZT", name: "Казахстанский тенге"),
        CurrencyEntity(id: "AED", name: "Дирхам ОАЭ")
    ]

    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        let upperIdentifiers = identifiers.map { $0.uppercased() }
        return Self.popularCurrencies.filter { upperIdentifiers.contains($0.id.uppercased()) }
    }

    func suggestedEntities() async throws -> [CurrencyEntity] {
        Self.popularCurrencies
    }
}
