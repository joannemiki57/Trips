import SwiftUI

/// Trip 상세 wrapper — Spine(기본) ↔ Feed(보조) 전환. mvp.md §6.2.
/// 사진 라우팅(NavigationLink → PhotoDetail/Cluster)은 두 자식 뷰가 동일하게 사용.
struct TripDetailView: View {
    let trip: Trip
    var loader: ThumbnailLoader

    @State private var mode: ViewMode = .spine
    @State private var pendingScrollDayId: UUID?
    @State private var isExportSheetPresented = false

    enum ViewMode: String, CaseIterable, Identifiable {
        case spine, feed
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            modeSwitcher
                .padding(.horizontal, TripsSpacing.l)
                .padding(.vertical, TripsSpacing.s)
                .background(TripsColor.bg)

            switch mode {
            case .spine:
                VisualSpineView(trip: trip, loader: loader, onJumpToDay: jumpToFeed)
            case .feed:
                DayFeedView(trip: trip, loader: loader, scrollToDayId: $pendingScrollDayId)
            }
        }
        .background(TripsColor.bg)
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isExportSheetPresented = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(String(localized: "export.openSheet"))
            }
        }
        .sheet(isPresented: $isExportSheetPresented) {
            ExportSheet(
                trip: trip,
                imageDataProvider: PhotoKitImageDataProvider()
            )
        }
    }

    private func jumpToFeed(_ day: Day) {
        pendingScrollDayId = day.id
        withAnimation(TripsMotion.transition) {
            mode = .feed
        }
    }

    private var modeSwitcher: some View {
        Picker("", selection: $mode) {
            SwiftUI.Label(
                String(localized: "tripdetail.mode.spine"),
                systemImage: "lines.measurement.vertical"
            ).tag(ViewMode.spine)
            SwiftUI.Label(
                String(localized: "tripdetail.mode.feed"),
                systemImage: "square.grid.2x2"
            ).tag(ViewMode.feed)
        }
        .pickerStyle(.segmented)
    }
}
