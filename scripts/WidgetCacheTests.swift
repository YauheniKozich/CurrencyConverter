import Foundation
import Testing
@testable import WidgetCacheCore

struct WidgetCacheTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func withCache(_ body: (WidgetRateCache, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("rates.json")
        try await body(WidgetRateCache(url: url), url)
    }

    private func entry(date: Date, rate: Double = 0.9) -> CurrencyWidgetEntry {
        CurrencyWidgetEntry(date: date, baseCurrency: "USD", rates: [
            WidgetRateItem(fromCurrency: "USD", toCurrency: "EUR", rate: rate, flagFrom: "", flagTo: "")
        ], ratesState: .current)
    }

    @Test(arguments: [0.0, 86_399.0, 86_400.0, 86_401.0, -1.0])
    func freshness(age: TimeInterval) async throws {
        try await withCache { cache, _ in
            let date = now.addingTimeInterval(-age)
            let request = await cache.beginRequest(at: date)
            #expect(await cache.save(entry(date: date), request: request))
            let loaded = await cache.load(now: now)
            #expect((loaded != nil) == (age >= 0 && age < WidgetRateCache.maximumSnapshotAge))
            if let loaded { #expect(loaded.date == date) }
        }
    }

    @Test(arguments: ["not json", "{}", "{\"date\":0,\"rates\":[]}",
                      "{\"version\":99,\"date\":0,\"rates\":[]}"])
    func corruptOrEmptyJSON(json: String) async throws {
        try await withCache { cache, url in
            let datedJSON = json.replacingOccurrences(of: "\"date\":0", with: "\"date\":\(now.timeIntervalSinceReferenceDate)")
            try Data(datedJSON.utf8).write(to: url)
            #expect(await cache.load(now: now) == nil)
        }
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity, -1.0, 0.0])
    func invalidRate(rate: Double) async throws {
        try await withCache { cache, url in
            let request = await cache.beginRequest(at: now)
            #expect(await cache.save(entry(date: now, rate: rate), request: request) == false)
            #expect(FileManager.default.fileExists(atPath: url.path) == false)
        }
    }

    @Test(arguments: ["NaN", "Infinity", "-Infinity", "-1", "0"])
    func invalidPersistedRate(value: String) async throws {
        try await withCache { cache, url in
            let request = await cache.beginRequest(at: now)
            #expect(await cache.save(entry(date: now), request: request))
            var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            var rates = try #require(json["rates"] as? [[String: Any]])
            rates[0]["rate"] = Double(value).flatMap { $0.isFinite ? $0 : nil }.map { $0 as Any } ?? value
            json["rates"] = rates
            try JSONSerialization.data(withJSONObject: json).write(to: url)
            #expect(await cache.load(now: now) == nil)
        }
    }

    @Test func newerRequestWinsEvenWhenOlderResponseArrivesLast() async throws {
        try await withCache { cache, _ in
            let old = await cache.beginRequest(at: now.addingTimeInterval(-10))
            let new = await cache.beginRequest(at: now.addingTimeInterval(-5))
            #expect(await cache.save(entry(date: now.addingTimeInterval(-1), rate: 0.95), request: new))
            #expect(await cache.save(entry(date: now, rate: 0.8), request: old) == false)
            let loaded = try #require(await cache.load(now: now))
            #expect(loaded.rates.first?.rate == 0.95)
            #expect(loaded.date == now.addingTimeInterval(-1))
        }
    }

    @Test func unknownVersionIsRejectedAndLegacySnapshotRemainsReadable() async throws {
        try await withCache { cache, url in
            let request = await cache.beginRequest(at: now)
            #expect(await cache.save(entry(date: now), request: request))
            var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            json["version"] = 99
            try JSONSerialization.data(withJSONObject: json).write(to: url)
            #expect(await cache.load(now: now) == nil)
            json.removeValue(forKey: "version")
            json.removeValue(forKey: "requestStartedAt")
            try JSONSerialization.data(withJSONObject: json).write(to: url)
            #expect(await cache.load(now: now)?.rates.first?.rate == 0.9)
        }
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func nonFiniteTimestampIsRejected(value: Double) async throws {
        try await withCache { cache, _ in
            let request = await cache.beginRequest(at: now)
            #expect(await cache.save(entry(date: Date(timeIntervalSince1970: value)), request: request) == false)
        }
    }

    @Test func timezoneAndLocaleDoNotChangeFreshnessOrStoredTimestamp() async throws {
        try await withCache { cache, _ in
            let request = await cache.beginRequest(at: now)
            #expect(await cache.save(entry(date: now), request: request))
            let date = try #require(await cache.load(now: now.addingTimeInterval(60))).date
            for locale in ["ru_RU", "en_US"] {
                for zone in ["Pacific/Kiritimati", "America/Los_Angeles"] {
                    let style = Date.FormatStyle(date: .numeric, time: .shortened,
                        locale: Locale(identifier: locale), timeZone: try #require(TimeZone(identifier: zone)))
                    #expect(!date.formatted(style).isEmpty)
                    #expect(date == now)
                }
            }
        }
    }
}
