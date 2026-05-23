import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            PhotoPermissionGate { TripListView() }
                .tabItem { SwiftUI.Label(String(localized: "tab.trips"), systemImage: "square.grid.2x2") }

            PlaceholderScreen(title: String(localized: "tab.settings"))
                .tabItem { SwiftUI.Label(String(localized: "tab.settings"), systemImage: "gearshape") }
        }
        .tint(TripsColor.accent)
    }
}

private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        NavigationStack {
            VStack(spacing: TripsSpacing.l) {
                Text("Trips")
                    .font(TripsFont.brand)
                    .foregroundStyle(TripsColor.textPrimary)
                Text(title)
                    .font(TripsFont.title)
                    .foregroundStyle(TripsColor.textSecondary)
                Text(verbatim: "W1 scaffold — features arrive in W3+")
                    .font(TripsFont.caption)
                    .foregroundStyle(TripsColor.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TripsColor.bg)
        }
    }
}

#Preview {
    RootView()
}
