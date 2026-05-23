import Foundation
import SwiftData

@Model
final class Day {
    @Attribute(.unique) var id: UUID
    var date: Date
    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Scene.day)
    var scenes: [Scene] = []

    @Relationship(deleteRule: .cascade, inverse: \Photo.day)
    var photos: [Photo] = []

    init(id: UUID = UUID(), date: Date, trip: Trip? = nil) {
        self.id = id
        self.date = date
        self.trip = trip
    }
}
