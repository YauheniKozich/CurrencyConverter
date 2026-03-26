import SwiftUI
import SwiftData

// MARK: - App Schema

private enum AppSchema {
    static let schema = Schema([Conversion.self, ExchangeRate.self])
}

// MARK: - App Entry Point

@main
struct CurrencyConverterApp: App {
    @State private var viewModel: ConverterViewModel?
    @State private var initError: Error?
    @State private var modelContainer: ModelContainer?
    @State private var dependencies: AppDependencies?

    var body: some Scene {
        WindowGroup {
            contentView
        }
        .modelContainer(modelContainer ?? defaultModelContainer)
    }

    private var defaultModelContainer: ModelContainer {
        makeDefaultModelContainer()
    }

    private var contentView: some View {
        Group {
            if let error = initError {
                errorView(error: error)
            } else if let viewModel = viewModel {
                ConverterView(viewModel: viewModel)
            } else {
                ProgressView("Инициализация...")
                    .task {
                        initializeApp()
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
                    initializeApp()
                }
            }
            .padding(.top)
        }
        .padding()
    }

    @MainActor
    private func initializeApp() {
        Task {
            do {
                let deps = try AppDependencies()
                let vm = try await deps.createConverterScreen()

                viewModel = vm
                dependencies = deps
                initError = nil
                modelContainer = deps.database
            } catch {
                initError = error
                viewModel = nil
                dependencies = nil
                modelContainer = nil
                Logger.log("Ошибка инициализации: \(error)", level: .error)
            }
        }
    }

    private func makeDefaultModelContainer() -> ModelContainer {
        if let container = try? ModelContainer(for: AppSchema.schema) {
            return container
        }

        Logger.log("Failed to create default ModelContainer, using in-memory", level: .warning)

        // Fallback: in-memory контейнер
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: AppSchema.schema, configurations: [configuration])
    }
}
