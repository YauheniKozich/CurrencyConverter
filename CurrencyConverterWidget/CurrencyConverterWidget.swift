//
//  CurrencyConverterWidget.swift
//  CurrencyConverterWidget
//
//  Created by Yauheni Kozich on 17.10.26.
//

import WidgetKit
import SwiftUI
import Security

// MARK: - Models

struct WidgetRateItem: Identifiable, Codable, Sendable {
    var id: String { "\(fromCurrency)_\(toCurrency)" }
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
    let flagFrom: String
    let flagTo: String

    var formattedRate: String {
        if rate >= 100 {
            return rate.formatted(.number.precision(.fractionLength(1)))
        } else if rate >= 1 {
            return rate.formatted(.number.precision(.fractionLength(2)))
        } else {
            return rate.formatted(.number.precision(.fractionLength(4)))
        }
    }
}

struct CurrencyWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let baseCurrency: String
    let rates: [WidgetRateItem]
    let ratesState: CurrencyWidgetRatesState
}

enum CurrencyWidgetRatesState: Sendable, Equatable {
    case current
    case cached
    case unavailable
    case placeholder
}

// MARK: - Last successful rates (no credentials)

actor WidgetRateCache {
    static let shared = WidgetRateCache()
    /// Fallback lifetime, independent of WidgetKit's refresh scheduling.
    static let maximumSnapshotAge: TimeInterval = 24 * 60 * 60

    struct Request: Sendable {
        let sequence: UInt64
        let startedAt: Date
    }

    private struct Snapshot: Codable {
        let version: Int?
        let date: Date
        let requestStartedAt: Date?
        let rates: [WidgetRateItem]
    }

    private let url: URL?
    private var nextSequence: UInt64 = 0
    private var latestSuccessfulSequence: UInt64 = 0

    init(url: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.currencyconverter")?
        .appendingPathComponent("widget-rates.json")) {
        self.url = url
    }

    func beginRequest(at date: Date) -> Request {
        nextSequence &+= 1
        return Request(sequence: nextSequence, startedAt: date)
    }

    func load(now: Date) -> CurrencyWidgetEntry? {
        guard let url, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.version == nil || snapshot.version == 1,
              !snapshot.rates.isEmpty,
              snapshot.rates.allSatisfy({ $0.rate.isFinite && $0.rate > 0 }) else { return nil }
        let age = now.timeIntervalSince(snapshot.date)
        guard age.isFinite, age >= 0, age < Self.maximumSnapshotAge else { return nil }
        return CurrencyWidgetEntry(
            date: snapshot.date, baseCurrency: "USD", rates: snapshot.rates, ratesState: .cached
        )
    }

    @discardableResult
    func save(_ entry: CurrencyWidgetEntry, request: Request) -> Bool {
        guard let url, entry.ratesState == .current,
              request.sequence >= latestSuccessfulSequence,
              !entry.rates.isEmpty,
              entry.rates.allSatisfy({ $0.rate.isFinite && $0.rate > 0 }),
              entry.date.timeIntervalSinceReferenceDate.isFinite,
              request.startedAt.timeIntervalSinceReferenceDate.isFinite,
              entry.date >= request.startedAt else { return false }
        do {
            let data = try JSONEncoder().encode(Snapshot(
                version: 1, date: entry.date, requestStartedAt: request.startedAt, rates: entry.rates
            ))
            // Only public rates: Keychain protection remains WhenUnlockedThisDeviceOnly.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            latestSuccessfulSequence = request.sequence
            return true
        } catch {
            print("Widget rate cache write failed: \\(error)")
            return false
        }
    }
}

#if !WIDGET_CACHE_TESTING
// MARK: - Timeline Provider

/// WidgetKit's callback API allows the handler to be retained until asynchronous work finishes.
/// The lock protects one-shot extraction before the handler crosses into the asynchronous task.
private final class OneShotTimelineCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: ((Timeline<CurrencyWidgetEntry>) -> Void)?

    init(_ completion: @escaping (Timeline<CurrencyWidgetEntry>) -> Void) {
        self.completion = completion
    }

    func callAsFunction(_ timeline: Timeline<CurrencyWidgetEntry>) {
        lock.lock()
        let handler = completion
        completion = nil
        lock.unlock()

        handler?(timeline)
    }
}

struct CurrencyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrencyWidgetEntry {
        CurrencyWidgetEntry(
            date: Date(),
            baseCurrency: "USD",
            rates: Self.defaultRates,
            ratesState: .placeholder
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrencyWidgetEntry) -> Void) {
        let entry = CurrencyWidgetEntry(
            date: Date(),
            baseCurrency: "USD",
            rates: Self.defaultRates,
            ratesState: .placeholder
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrencyWidgetEntry>) -> Void) {
        let completionHandler = OneShotTimelineCompletion(completion)
        Task {
            let entry = await fetchRates()
            // Retry transient failures sooner; WidgetKit still controls the actual schedule.
            let interval: TimeInterval = entry.ratesState == .current ? 1800 : 300
            let nextUpdate = Date().addingTimeInterval(interval)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completionHandler(timeline)
        }
    }

    private func fetchRates() async -> CurrencyWidgetEntry {
        let cache = WidgetRateCache.shared
        let cacheRequest = await cache.beginRequest(at: Date())
        let keyResult = loadAPIKey()
        let apiKey: String
        switch keyResult.status {
        case errSecSuccess:
            guard let value = keyResult.key, !value.isEmpty else { return unavailableEntry() }
            apiKey = value
        case errSecItemNotFound:
            // A missing key is distinct from a temporarily locked Keychain.
            return unavailableEntry()
        case errSecInteractionNotAllowed, errSecNotAvailable:
            return (await cache.load(now: Date())) ?? unavailableEntry()
        default:
            return (await cache.load(now: Date())) ?? unavailableEntry()
        }

        guard let url = URL(string: "https://api.currencyapi.com/v3/latest?base_currency=USD&currencies=EUR,GBP,JPY,RUB") else {
            return unavailableEntry()
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (await cache.load(now: Date())) ?? unavailableEntry()
            }
            guard http.statusCode == 200 else {
                if http.statusCode == 408 || http.statusCode == 429 || (500...599).contains(http.statusCode) {
                    return (await cache.load(now: Date())) ?? unavailableEntry()
                }
                return unavailableEntry()
            }

            struct ApiResponse: Decodable {
                struct RateData: Decodable {
                    let code: String
                    let value: Double
                }
                let data: [String: RateData]
            }

            let decoded = try JSONDecoder().decode(ApiResponse.self, from: data)
            let requestedRates: [(code: String, flag: String)] = [
                ("EUR", "🇪🇺"),
                ("GBP", "🇬🇧"),
                ("JPY", "🇯🇵"),
                ("RUB", "🇷🇺")
            ]
            var items: [WidgetRateItem] = []
            for requested in requestedRates {
                guard let rate = decoded.data[requested.code]?.value,
                      rate.isFinite,
                      rate > 0 else {
                    return unavailableEntry()
                }
                items.append(
                    WidgetRateItem(
                        fromCurrency: "USD",
                        toCurrency: requested.code,
                        rate: rate,
                        flagFrom: "🇺🇸",
                        flagTo: requested.flag
                    )
                )
            }
            let entry = CurrencyWidgetEntry(date: Date(), baseCurrency: "USD", rates: items, ratesState: .current)
            if await cache.save(entry, request: cacheRequest) { return entry }
            // A newer successful request may have committed while this request awaited the network.
            return (await cache.load(now: Date())) ?? entry
        } catch {
            return (await cache.load(now: Date())) ?? unavailableEntry()
        }
    }

    private func unavailableEntry() -> CurrencyWidgetEntry {
        CurrencyWidgetEntry(date: Date(), baseCurrency: "USD", rates: [], ratesState: .unavailable)
    }

    private func loadAPIKey() -> (status: OSStatus, key: String?) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.yourapp.currencyconverter",
            kSecAttrAccount: "CurrencyAPIKey",
            kSecAttrAccessGroup: "TLP4S46XK2.qwerty.CurrencyConverterTest",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return (status, nil)
        }
        return (status, String(data: data, encoding: .utf8))
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

    private var primaryRate: WidgetRateItem? {
        entry.rates.first
    }

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

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let primaryRate {
                HStack(spacing: 6) {
                    Text(primaryRate.flagFrom)
                        .font(.title3)
                    Image(systemName: "arrow.right")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    Text(primaryRate.flagTo)
                        .font(.title3)
                    Spacer()
                    if entry.ratesState == .placeholder {
                        Text("Пример")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
            } else {
                unavailableView
            }

            if entry.ratesState == .cached {
                Text("Сохранённые курсы")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack {
                if entry.ratesState == .cached {
                    Text(entry.date, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(entry.date, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
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
                if entry.ratesState == .current {
                    Text(entry.date, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if entry.ratesState == .cached {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Сохранённые курсы")
                        Text(entry.date, format: .dateTime.year().month().day().hour().minute())
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else if entry.ratesState == .placeholder {
                    Text("Пример")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if entry.rates.isEmpty {
                unavailableView
            } else {
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
        }
        .padding(2)
    }

    private var unavailableView: some View {
        Label("Курсы недоступны", systemImage: "wifi.slash")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityLabel("Курсы валют недоступны")
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
    CurrencyWidgetEntry(date: .now, baseCurrency: "USD", rates: CurrencyWidgetProvider.defaultRates, ratesState: .placeholder)
}

#Preview(as: .systemMedium) {
    CurrencyConverterWidget()
} timeline: {
    CurrencyWidgetEntry(date: .now, baseCurrency: "USD", rates: CurrencyWidgetProvider.defaultRates, ratesState: .placeholder)
}

#endif
