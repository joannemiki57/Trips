import Foundation
import SwiftData

@Model
final class Photo {
    @Attribute(.unique) var id: UUID
    var assetLocalId: String
    var capturedAt: Date
    var isFavorite: Bool

    var memo: String?

    var sharpness: Double?
    var score: Double?
    var scoreVersion: Int?

    var isMissing: Bool
    var lastVerifiedAt: Date?

    var day: Day?
    var scene: Scene?

    @Relationship(inverse: \Label.photos)
    var labels: [Label] = []

    init(
        id: UUID = UUID(),
        day: Day,
        assetLocalId: String,
        capturedAt: Date,
        scene: Scene? = nil,
        isFavorite: Bool = false,
        memo: String? = nil
    ) {
        self.id = id
        self.day = day
        self.scene = scene
        self.assetLocalId = assetLocalId
        self.capturedAt = capturedAt
        self.isFavorite = isFavorite
        self.memo = memo
        self.isMissing = false
    }

    var allLabels: [Label] {
        let own = Set(labels.map(\.id))
        let sceneLabels = scene?.labels ?? []
        return labels + sceneLabels.filter { !own.contains($0.id) }
    }
}
