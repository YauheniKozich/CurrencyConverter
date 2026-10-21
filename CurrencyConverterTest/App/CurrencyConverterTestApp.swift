import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct CurrencyConverterApp: App {
    @State private var viewModel: ConverterViewModel?
    @State private var initError: (any Error)?
    @State private var modelContainer: ModelContainer?
    @State private var historyViewModel: HistoryViewModel?
    @State private var isInitializing = false
    @State private var showAPIKeySheet = false

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                contentView
                    .modelContainer(modelContainer)
            } else {
                contentView
            }
        }
    }

    private var contentView: some View {
        Group {
            if let error = initError {
                errorView(error: error)
            } else if let viewModel, let historyViewModel {
                ConverterView(
                    viewModel: viewModel,
                    historyViewModel: historyViewModel,
                    onAPIKeySaved: {
                        Task { await initializeApp() }
                    }
                )
                .id(ObjectIdentifier(viewModel))
            } else {
                ProgressView("Инициализация...")
                    .task {
                        await initializeApp()
                    }
            }
        }
    }

    private func errorView(error: any Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Ошибка")
                .font(.headline)

            // Используем user-friendly сообщение из AppError
            let message = (error as? AppError)?.errorDescription ?? error.localizedDescription
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Показываем рекомендацию только для AppError
            if let appError = error as? AppError,
               let suggestion = appError.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button {
                    showAPIKeySheet = true
                } label: {
                    Label("Ввести API ключ", systemImage: "key.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("Попробовать снова") {
                    Task {
                        await initializeApp()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
        }
        .padding()
        .sheet(isPresented: $showAPIKeySheet) {
            APIKeyInputSheet { _ in
                Task {
                    await initializeApp()
                }
            }
        }
    }

    @MainActor
    private func makeDependencies() async throws -> AppDependencies {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-history") {
            let schema = Schema([Conversion.self, ExchangeRate.self])
            let container = try ModelContainer(
                for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let configuration = try AppConfiguration(
                apiKey: "ui-fixture", apiBaseURL: ConfigurationDefaults.defaultBaseURL
            )
            let dependencies = AppDependencies(
                config: configuration, database: container, repository: HistoryUITestRepository()
            )
            try await dependencies.createSaveHistoryUseCase().execute(
                from: "USD", to: "EUR", amount: 12.5, result: 11.5, rate: 0.92
            )
            return dependencies
        }
        #endif
        if let modelContainer {
            return AppDependencies(config: try AppConfiguration(), database: modelContainer)
        }
        return try AppDependencies()
    }

    @MainActor
    private func initializeApp() async {
        guard !isInitializing else { return }
        isInitializing = true
        defer { isInitializing = false }

        let previousAmount = viewModel?.amount
        viewModel?.cancelConversion()

        do {
            let deps = try await makeDependencies()
            let converterViewModel = try await deps.createConverterScreen()
            let historyViewModel = try deps.createHistoryScreen()

            if let previousAmount {
                converterViewModel.setAmount(previousAmount)
            }
            AppDependencies.setShared(deps)
            self.viewModel = converterViewModel
            self.historyViewModel = historyViewModel
            self.modelContainer = deps.database
            initError = nil
        } catch {
            initError = error
            viewModel = nil
            historyViewModel = nil
            modelContainer = nil
            Logger.log("Ошибка инициализации: \(error)", level: .error)
        }
    }
}

#if DEBUG
/// Deterministic UI fixture: no network requests, credentials or persistent user data.
private struct HistoryUITestRepository: CurrencyRepository {
    func fetchSupportedCurrencies() async throws -> [String: Currency] {
        ["USD": Currency(code: "USD", name: "US Dollar"), "EUR": Currency(code: "EUR", name: "Euro")]
    }

    func refreshSupportedCurrencies() async throws -> [String: Currency] {
        try await fetchSupportedCurrencies()
    }

    func convert(from: String, to: String, amount: Double) async throws -> ConversionResult {
        ConversionResult(result: amount * 0.92, rate: 0.92)
    }
}
#endif
