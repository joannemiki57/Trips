import Foundation
import SwiftData

enum TripsModelContainer {
    static let schema = Schema([
        Trip.self,
        Day.self,
        Scene.self,
        Photo.self,
        Label.self,
        UserSettings.self
    ])

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
