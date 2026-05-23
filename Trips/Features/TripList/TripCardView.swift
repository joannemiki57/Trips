import SwiftUI
import UIKit

/// 한 Trip 카드. 커버 사진 + 이름 + 날짜 범위 + 사진 수.
/// 커버 = `trip.coverPhoto` 또는 폴백(첫 Day 첫 Photo) — C2 LOCKED 규칙은 UI 레이어 계산.
struct TripCardView: View {
    let trip: Trip
    var loader: ThumbnailLoader
    var onRename: () -> Void = {}

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            info
        }
        .background(TripsColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: TripsRadius.card))
        .contextMenu {
            Button {
                onRename()
            } label: {
                SwiftUI.Label(
                    String(localized: "triplist.rename"),
                    systemImage: "pencil"
                )
            }
        }
    }

    private var cover: some View {
        ZStack {
            Rectangle()
                .fill(TripsColor.surface)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(TripsColor.textSecondary)
            }
        }
        .frame(height: 200)
        .clipped()
        .task(id: trip.id) {
            guard let assetId = coverAssetLocalId else { return }
            thumbnail = await loader.thumbnail(
                assetLocalId: assetId,
                size: CGSize(width: 400, height: 200)
            )
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: TripsSpacing.xs) {
            Text(trip.name)
                .font(TripsFont.title)
                .foregroundStyle(TripsColor.textPrimary)
            HStack(spacing: TripsSpacing.s) {
                Text(dateRange)
                    .font(TripsFont.caption)
                    .foregroundStyle(TripsColor.textSecondary)
                Text("·")
                    .font(TripsFont.caption)
                    .foregroundStyle(TripsColor.textSecondary)
                Text(String(localized: "triplist.photoCount \(photoCount)"))
                    .font(TripsFont.caption)
                    .foregroundStyle(TripsColor.textSecondary)
            }
        }
        .padding(TripsSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var coverAssetLocalId: String? {
        if let cover = trip.coverPhoto {
            return cover.assetLocalId
        }
        return trip.days.first?.photos.first?.assetLocalId
    }

    private var photoCount: Int {
        trip.days.reduce(0) { $0 + $1.photos.count }
    }

    private var dateRange: String {
        let style = Date.FormatStyle()
            .month(.abbreviated)
            .day()
            .year(.defaultDigits)
        let start = trip.startDate.formatted(style)
        let end = trip.endDate.formatted(style)
        if start == end {
            return start
        }
        return "\(start) – \(end)"
    }
}
