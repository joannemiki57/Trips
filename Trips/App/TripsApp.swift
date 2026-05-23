import SwiftUI
import SwiftData

@main
struct TripsApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try TripsModelContainer.make()
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
