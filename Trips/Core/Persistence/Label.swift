import Foundation
import SwiftData

@Model
final class Label {
    @Attribute(.unique) var id: UUID
    var name: String
    var source: LabelSource

    @Relationship var scenes: [Scene] = []
    @Relationship var photos: [Photo] = []

    init(id: UUID = UUID(), name: String, source: LabelSource) {
        self.id = id
        self.name = name
        self.source = source
    }
}

enum LabelSource: String, Codable {
    case builtIn
    case userDefined
}
