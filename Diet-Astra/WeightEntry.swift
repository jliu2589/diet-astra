import Foundation

struct WeightEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let pounds: Double

    init(id: UUID = UUID(), date: Date = .now, pounds: Double) {
        self.id = id
        self.date = date
        self.pounds = pounds
    }
}
