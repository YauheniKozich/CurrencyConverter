//
//  CurrencyConverterWidget.swift
//  CurrencyConverterWidget
//
//  Created by Yauheni Kozich on 17.10.26.
//

import WidgetKit
import SwiftUI

// MARK: - Models

struct WidgetRateItem: Identifiable, Sendable {
    var id: String { "\(fromCurrency)_\(toCurrency)" }
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
    let flagFrom: String
    let flagTo: String

    var formattedRate: String {
        if rate >= 100 {
            return String(format: "%.1f", rate)
        } else if rate >= 1 {
            return String(format: "%.2f", rate)
        } else {
            return String(format: "%.4f", rate)
        }
    }
}

struct CurrencyWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let baseCurrency: String
    let rates: [WidgetRateItem]
    let isOffline: Bool
}

// MARK: - Timeline Provider

struct CurrencyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrencyWidgetEntry {
        CurrencyWidgetEntry(
            date: Date(),
            baseCurrency: "USD",
            rates: Self.defaultRates,
            isOffline: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrencyWidgetEntry) -> Void) {
        let entry = CurrencyWidgetEntry(
            date: Date(),
            baseCurrency: "USD",
            rates: Self.defaultRates,
            isOffline: false
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrencyWidgetEntry>) -> Void) {
        Task {
            let entry = await fetchRates()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchRates() async -> CurrencyWidgetEntry {
        let apiKey = UserDefaults(suiteName: "group.com.currencyconverter")?.string(forKey: "CurrencyAPIKey")
            ?? UserDefaults.standard.string(forKey: "CurrencyAPIKey")

        guard let apiKey, !apiKey.isEmpty else {
            return CurrencyWidgetEntry(date: Date(), baseCurrency: "USD", rates: Self.defaultRates, isOffline: false)
        }

        guard let url = URL(string: "https://api.currencyapi.com/v3/latest?base_currency=USD&currencies=EUR,GBP,JPY,RUB") else {
            return CurrencyWidgetEntry(date: Date(), baseCurrency: "USD", rates: Self.defaultRates, isOffline: true)
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return CurrencyWidgetEntry(date: Date(), baseCurrency: "USD", rates: Self.defaultRates, isOffline: true)
            }

            struct ApiResponse: Decodable {
                struct RateData: Decodable {
                    let code: String
                    let value: Double
                }
                let data: [String: RateData]
            }

            let decoded = try JSONDecoder().decode(ApiResponse.self, from: data)
            let items: [WidgetRateItem] = [
                WidgetRateItem(fromCurrency: "USD", toCurrency: "EUR", rate: decoded.data["EUR"]?.value ?? 0.92, flagFrom: "🇺🇸", flagTo: "🇪🇺"),
                WidgetRateItem(fromCurrency: "USD", toCurrency: "GBP", rate: decoded.data["GBP"]?.value ?? 0.79, flagFrom: "🇺🇸", flagTo: "🇬🇧"),
                WidgetRateItem(fromCurrency: "USD", toCurrency: "JPY", rate: decoded.data["JPY"]?.value ?? 154.2, flagFrom: "🇺🇸", flagTo: "🇯🇵"),
                WidgetRateItem(fromCurrency: "USD", toCurrency: "RUB", rate: decoded.data["RUB"]?.value ?? 96.5, flagFrom: "🇺🇸", flagTo: "🇷🇺")
            ]
            return CurrencyWidgetEntry(date: Date(), baseCurrency: "USD", rates: items, isOffline: false)
        } catch {
            return CurrencyWidgetEntry(date: Date(), baseCurrency: "USD", rates: Self.defaultRates, isOffline: true)
        }
    }

    static let defaultRates: [WidgetRateItem] = [
        WidgetRateItem(fromCurrency: "USD", toCurrency: "EUR", rate: 0.92, flagFrom: "🇺🇸", flagTo: "🇪🇺"),
        WidgetRateItem(fromCurrency: "USD", toCurrency: "GBP", rate: 0.79, flagFrom: "🇺🇸", flagTo: "🇬🇧"),
        WidgetRateItem(fromCurrency: "USD", toCurrency: "JPY", rate: 154.2, flagFrom: "🇺🇸", flagTo: "🇯🇵"),
        WidgetRateItem(fromCurrency: "USD", toCurrency: "RUB", rate: 96.5, flagFrom: "🇺🇸", flagTo: "🇷🇺")
    ]
}

// MARK: - Widget View

struct CurrencyConverterWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: CurrencyWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var primaryRate: WidgetRateItem {
        entry.rates.first ?? WidgetRateItem(fromCurrency: "USD", toCurrency: "EUR", rate: 0.92, flagFrom: "🇺🇸", flagTo: "🇪🇺")
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(primaryRate.flagFrom)
                    .font(.title3)
                Image(systemName: "arrow.right")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Text(primaryRate.flagTo)
                    .font(.title3)
                Spacer()
                if entry.isOffline {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("1 \(primaryRate.fromCurrency) =")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(primaryRate.formattedRate)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(primaryRate.toCurrency)
                    .font(.subheadline.bold())
                    .foregroundColor(.accentColor)
            }

            Spacer(minLength: 0)

            HStack {
                Text(entry.date, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(4)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Курсы валют", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                if entry.isOffline {
                    Label("Офлайн", systemImage: "wifi.slash")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(entry.date, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(entry.rates) { item in
                    HStack(spacing: 8) {
                        Text(item.flagTo)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(item.fromCurrency)/\(item.toCurrency)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            Text(item.formattedRate)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                    .padding(6)
                    .background(Color(.secondarySystemFill).opacity(0.5))
                    .cornerRadius(8)
                }
            }
        }
        .padding(2)
    }
}

// MARK: - Widget Definition

struct CurrencyConverterWidget: Widget {
    let kind: String = "CurrencyConverterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrencyWidgetProvider()) { entry in
            CurrencyConverterWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Курсы валют")
        .description("Актуальные курсы популярных валют на вашем экране.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    CurrencyConverterWidget()
} timeline: {
    CurrencyWidgetEntry(date: .now, baseCurrency: "USD", rates: CurrencyWidgetProvider.defaultRates, isOffline: false)
}

#Preview(as: .systemMedium) {
    CurrencyConverterWidget()
} timeline: {
    CurrencyWidgetEntry(date: .now, baseCurrency: "USD", rates: CurrencyWidgetProvider.defaultRates, isOffline: false)
}
