import SwiftUI
import SwiftData

@main
struct CurrencyConverterApp: App {
    @State private var dependencyContainer: DependencyContainerProtocol?

    var body: some Scene {
        WindowGroup {
            if let container = dependencyContainer {
                switch container.makeConverterViewModel() {
                case .success(let viewModel):
                    ConverterView(viewModel: viewModel)
                        .environment(\.modelContext, container.modelContext)
                case .failure(let error):
                    VStack {
                        Text("Ошибка инициализации приложения")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView("Инициализация...")
                    .onAppear {
                        Task { @MainActor in
                            do {
                                dependencyContainer = try DependencyContainer()
                            } catch {
                                // В реальном приложении здесь должна быть обработка ошибки
                                fatalError("Failed to create DependencyContainer: \(error)")
                            }
                        }
                    }
            }
        }
        .modelContainer(for: [Conversion.self, ExchangeRate.self])
    }
}
