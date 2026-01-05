import SwiftUI
import SwiftData

@main
struct CurrencyConverterApp: App {
    @State private var dependencies: Dependencies?
    @State private var viewModel: ConverterViewModel?
    @State private var initError: Error?
    
    var body: some Scene {
        WindowGroup {
            contentView
        }
        .modelContainer(createModelContainer())
    }
    
    private var contentView: some View {
        Group {
            if let error = initError {
                errorView(error: error)
            } else if let viewModel = viewModel {
                ConverterView(viewModel: viewModel)
                    .environment(\.modelContext, dependencies?.dbContext ?? createModelContext())
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
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let localizedError = error as? LocalizedError,
               let suggestion = localizedError.recoverySuggestion {
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
        do {
            let deps = try AppDependencies()
            
            let vm = try deps.createConverterScreen()
            
            dependencies = deps
            viewModel = vm
            initError = nil
        } catch {
            initError = error
            viewModel = nil
            dependencies = nil
            print("Ошибка инициализации: \(error)")
        }
    }
    
    private func createModelContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Conversion.self, ExchangeRate.self)
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }
    
    private func createModelContext() -> ModelContext {
        ModelContext(createModelContainer())
    }
}
