import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct CurrencyConverterApp: App {
    @State private var viewModel: ConverterViewModel?
    @State private var initError: Error?
    @State private var modelContainer: ModelContainer?
    @State private var historyViewModel: HistoryViewModel?
    @State private var isInitializing = false

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
                ConverterView(viewModel: viewModel, historyViewModel: historyViewModel)
            } else {
                ProgressView("Инициализация...")
                    .task {
                        await initializeApp()
                    }
            }
        }
    }

    private func errorView(error: Error) -> some View {
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

            Button("Попробовать снова") {
                Task {
                    await initializeApp()
                }
            }
            .padding(.top)
        }
        .padding()
    }

    @MainActor
    private func initializeApp() async {
        guard !isInitializing else { return }
        isInitializing = true
        defer { isInitializing = false }

        do {
            let deps = try AppDependencies()
            let converterViewModel = try await deps.createConverterScreen()
            let historyViewModel = try deps.createHistoryScreen()

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
