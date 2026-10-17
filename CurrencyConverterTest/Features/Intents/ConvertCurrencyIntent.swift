//
//  ConvertCurrencyIntent.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 17.10.26.
//

import AppIntents
import Foundation

struct ConvertCurrencyIntent: AppIntent {
    static let title: LocalizedStringResource = "Конвертировать валюту"
    static let description = IntentDescription("Конвертирует сумму из одной валюты в другую")

    @Parameter(title: "Сумма", default: 100.0)
    var amount: Double

    @Parameter(title: "Из валюты")
    var fromCurrency: CurrencyEntity

    @Parameter(title: "В валюту")
    var toCurrency: CurrencyEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Конвертировать (\(\.$amount)) (\(\.$fromCurrency)) в (\(\.$toCurrency))")
    }

    init() {}

    init(amount: Double, fromCurrency: CurrencyEntity, toCurrency: CurrencyEntity) {
        self.amount = amount
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
    }

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<Double> {
        let dependencies = try AppDependencies.shared
        let conversionUseCase = try dependencies.createConversionUseCase()
        let saveHistoryUseCase = try dependencies.createSaveHistoryUseCase()

        let fromCode = fromCurrency.id.uppercased()
        let toCode = toCurrency.id.uppercased()

        let result = try await conversionUseCase.execute(
            from: fromCode,
            to: toCode,
            amount: amount
        )

        // Сохраняем конвертацию в историю
        try? await saveHistoryUseCase.execute(
            from: fromCode,
            to: toCode,
            amount: amount,
            result: result.result,
            rate: result.rate
        )

        let formatter = NumberFormatterService(locale: .current)
        let formattedAmount = formatter.format(amount)
        let formattedResult = formatter.format(result.result)

        let offlineNotice = result.isStaleRate ? String(localized: " (сохранённый курс)") : ""
        let dialogText = "\(formattedAmount) \(fromCode) = \(formattedResult) \(toCode)\(offlineNotice)"

        return .result(
            value: result.result,
            dialog: IntentDialog(stringLiteral: dialogText)
        )
    }
}
