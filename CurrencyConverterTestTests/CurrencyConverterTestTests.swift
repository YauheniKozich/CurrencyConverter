import XCTest
@testable import CurrencyConverterTest
import SwiftData

// Кастомный URLProtocol для моков
class MockURLProtocol: URLProtocol {
    static var handlers: [String: ((URLRequest) throws -> (HTTPURLResponse, Data))] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url?.absoluteString,
              let handler = MockURLProtocol.handlers[url] else {
            XCTFail("No handler for URL: \(request.url?.absoluteString ?? "unknown")")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

class MockLocalDataSource: CurrencyLocalDataStoring {
    var cachedRate: ExchangeRate?
    var savedRate: (from: String, to: String, rate: Double)?
    func loadCachedRate(from: String, to: String) throws -> ExchangeRate? {
        return cachedRate
    }
    func saveRate(from: String, to: String, rate: Double) throws {
        savedRate = (from, to, rate)
    }
}

class MockAPIKeyProvider: APIKeyProviding {
    func initializeAPIKeyIfNeeded() {
        //
    }
    
    var apiKey: String? = "TEST_API_KEY"
    func loadAPIKey() -> String? { apiKey }
    func saveAPIKey(_ key: String) { self.apiKey = key }
}

final class CurrencyAPIRepositoryTests: XCTestCase {
    var context: ModelContext!
    var repository: CurrencyAPIRepository!
    var testConfig: AppConfiguration!

    override func setUp() async throws {
        testConfig = TestHelpers.makeTestConfiguration()

        let schema = Schema([Conversion.self, ExchangeRate.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        _ = URLSession(configuration: config)

        let localDataSource = MockLocalDataSource()
        let networkService = NetworkService(session: URLSession(configuration: config))
        let apiKeyProvider = MockAPIKeyProvider()
        repository = try CurrencyAPIRepository(
            context: context,
            localDataSource: localDataSource,
            networkService: networkService,
            apiKeyProvider: apiKeyProvider,
            apiKey: testConfig.apiKey,
            apiBaseURL: testConfig.apiBaseURL,
            cacheTTL: testConfig.cacheTTL
        )
    }

    override func tearDown() {
        repository = nil
        context = nil
        MockURLProtocol.handlers = [:]
        // Сбрасываем protocolClasses, чтобы не влиять на другие тесты
        URLSessionConfiguration.ephemeral.protocolClasses = []
        super.tearDown()
    }

    func testConvertSuccess() async throws {
        let jsonString = """
        {
            "meta": { "last_updated_at": "2025-05-20T12:00:00Z" },
            "data": {
                "EUR": { "code": "EUR", "value": 0.9 }
            }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let url = "https://api.test.com/v3/latest?apikey=test_api_key&base_currency=USD&currencies=EUR"

        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }

        let result = try await repository.convert(from: "USD", to: "EUR", amount: 10)
        XCTAssertEqual(result.rate, 0.9)
        XCTAssertEqual(result.result, 9.0, accuracy: 0.001)

        // Проверка кэширования
        let rates = try context.fetch(FetchDescriptor<ExchangeRate>())
        XCTAssertEqual(rates.count, 1, "Expected one cached rate")
        XCTAssertEqual(rates.first?.rate, 0.9, "Cached rate should match API response")
    }

    func testConvertRetriesAndFallbackToCache() async throws {
        // Вставим в кэш данные
        let cachedRate = ExchangeRate(from: "USD", to: "EUR", rate: 0.8, timestamp: Date())
        context.insert(cachedRate)
        try context.save()

        var callCount = 0
        let url = "https://api.test.com/v3/latest?apikey=test_api_key&base_currency=USD&currencies=EUR"
        MockURLProtocol.handlers[url] = { _ in
            callCount += 1
            let response = HTTPURLResponse(url: URL(string: "https://api.currencyapi.com")!,
                                          statusCode: 500,
                                          httpVersion: nil,
                                          headerFields: ["Content-Type": "application/json"])!
            let data = "{\"error\": \"Internal Server Error\"}".data(using: .utf8)!
            return (response, data)
        }

        let result = try await repository.convert(from: "USD", to: "EUR", amount: 10)
        XCTAssertEqual(result.rate, 0.8)
        XCTAssertEqual(result.result, 8.0, accuracy: 0.001)
        XCTAssertEqual(callCount, 5, "Expected exactly 5 retries") // Устанавливаем 5, так как maxRetries = 5

        // Проверка, что кэш не изменился
        let rates = try context.fetch(FetchDescriptor<ExchangeRate>())
        XCTAssertEqual(rates.count, 1, "Cache should not be modified")
        XCTAssertEqual(rates.first?.rate, 0.8, "Cached rate should remain unchanged")
    }

    func testConvertInvalidJSON() async throws {
        let url = "https://api.test.com/v3/latest?apikey=test_api_key&base_currency=USD&currencies=EUR"
        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            let data = "invalid json".data(using: .utf8)!
            return (response, data)
        }

        do {
            _ = try await repository.convert(from: "USD", to: "EUR", amount: 10)
            XCTFail("Expected error for invalid JSON")
        } catch {
            XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(error)")
        }
    }

    func testFetchSupportedCurrenciesSuccess() async throws {
        let jsonString = """
        {
            "meta": { "last_updated_at": "2025-05-20T12:00:00Z" },
            "data": {
                "USD": { "name": "US Dollar", "code": "USD" },
                "EUR": { "name": "Euro", "code": "EUR" }
            }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let url = "https://api.test.com/v3/currencies?apikey=test_api_key"

        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }

        let currencies = try await repository.fetchSupportedCurrencies()
        XCTAssertEqual(currencies["USD"]?.name, "US Dollar")
        XCTAssertEqual(currencies["EUR"]?.code, "EUR")
    }

    func testFetchSupportedCurrenciesEmpty() async throws {
        let jsonString = """
        {
            "meta": { "last_updated_at": "2025-05-20T12:00:00Z" },
            "data": {}
        }
        """
        let data = jsonString.data(using: .utf8)!
        let url = "https://api.test.com/v3/currencies?apikey=test_api_key"

        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }

        let currencies = try await repository.fetchSupportedCurrencies()
        XCTAssertTrue(currencies.isEmpty, "Expected empty currencies list")
    }

    func testConvertWithStaleCacheFallsBackToAPI() async throws {
        // Кэш со старой датой
        let oldDate = Date(timeIntervalSinceNow: -3600)
        let cachedRate = ExchangeRate(from: "USD", to: "EUR", rate: 0.7, timestamp: oldDate)
        context.insert(cachedRate)
        try context.save()

        let jsonString = """
        {
            "meta": { "last_updated_at": "2025-05-20T12:00:00Z" },
            "data": {
                "EUR": { "code": "EUR", "value": 0.95 }
            }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let url = "https://api.test.com/v3/latest?apikey=test_api_key&base_currency=USD&currencies=EUR"
        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }

        let result = try await repository.convert(from: "USD", to: "EUR", amount: 10)
        XCTAssertEqual(result.rate, 0.95)
        XCTAssertEqual(result.result, 9.5, accuracy: 0.001)
    }

    func testConvertNoInternetAndNoCacheFails() async throws {
        let url = "https://api.test.com/v3/latest?apikey=test_api_key&base_currency=USD&currencies=EUR"
        MockURLProtocol.handlers[url] = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await repository.convert(from: "USD", to: "EUR", amount: 10)
            XCTFail("Expected failure when no internet and no cache")
        } catch let error as CurrencyAPIRepositoryError {
            XCTAssertEqual(error, .noCacheAvailable)
        } catch {
            XCTFail("Expected CurrencyAPIRepositoryError.noCacheAvailable, got \(error)")
        }
    }

    func testFetchSupportedCurrenciesPartialData() async throws {
        let jsonString = """
        {
            "meta": { "last_updated_at": "2025-05-20T12:00:00Z" },
            "data": {
                "USD": { "code": "USD" },
                "EUR": { "name": "Euro", "code": "EUR" }
            }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let url = "https://api.test.com/v3/currencies?apikey=test_api_key"

        MockURLProtocol.handlers[url] = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }

        let currencies = try await repository.fetchSupportedCurrencies()
        XCTAssertEqual(currencies["EUR"]?.name, "Euro")
        XCTAssertNil(currencies["USD"]?.name)
    }
}
