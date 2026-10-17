import Foundation

struct ConversionHistoryEntry: Identifiable, Sendable {
    let id: UUID
    let from: String
    let to: String
    let amount: Double
    let result: Double
    let rate: Double
    let date: Date

    init(
        id: UUID = UUID(),
        from: String,
        to: String,
        amount: Double,
        result: Double,
        rate: Double,
        date: Date = Date()
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.amount = amount
        self.result = result
        self.rate = rate
        self.date = date
    }
}
