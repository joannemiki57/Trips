import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var homeAnchorLat: Double?
    var homeAnchorLon: Double?
    var showSinglePhotoAsScene: Bool

    init(
        id: UUID = UUID(),
        homeAnchorLat: Double? = nil,
        homeAnchorLon: Double? = nil,
        showSinglePhotoAsScene: Bool = false
    ) {
        self.id = id
        self.homeAnchorLat = homeAnchorLat
        self.homeAnchorLon = homeAnchorLon
        self.showSinglePhotoAsScene = showSinglePhotoAsScene
    }
}
