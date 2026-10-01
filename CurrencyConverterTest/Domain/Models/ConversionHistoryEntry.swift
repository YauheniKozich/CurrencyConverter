import Foundation

struct ConversionHistoryEntry: Identifiable, Sendable {
    let id: UUID
    let from: String
    let to: String
    let amount: Double
    let result: Double
    let rate: Double
    let date: Date
}
