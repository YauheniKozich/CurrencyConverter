import SwiftUI
import SwiftData

@main
struct CurrencyConverterApp: App {
    let context: ModelContext

    init() {
        do {
            let container = try ModelContainer(for: Conversion.self, ExchangeRate.self)
            context = ModelContext(container)
        } catch {
            fatalError("Failed to create ModelContext: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ConverterView(viewModel: ViewModelFactory.makeConverterViewModel(context: context))
                .environment(\.modelContext, context)
        }
        .modelContainer(for: [Conversion.self, ExchangeRate.self])
    }
}
