import Foundation
import SwiftData

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var coverPhoto: Photo?

    @Relationship(deleteRule: .cascade, inverse: \Day.trip)
    var days: [Day] = []

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        coverPhoto: Photo? = nil
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.coverPhoto = coverPhoto
    }
}
