import SwiftUI

/// 여행의 세로 척추 — mvp.md §5.4 / §6.2. 각 Day = 마디(node) + 옆에 favorite 사진 가로 스트립.
/// favorite 많을수록 마디 굵게, 정리 안 된 Day(♥ 0개)는 옅게 + 안내문.
/// 사진 탭 → PhotoDetail/Cluster 동일 라우팅.
struct VisualSpineView: View {
    let trip: Trip
    var loader: ThumbnailLoader

    private var sortedDays: [Day] {
        trip.days.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sortedDays.enumerated()), id: \.element.id) { index, day in
                    SpineNodeRow(
                        day: day,
                        loader: loader,
                        isFirst: index == 0,
                        isLast: index == sortedDays.count - 1
                    )
                }
            }
            .padding(.vertical, TripsSpacing.l)
        }
        .background(TripsColor.bg)
    }
}

/// Spine의 한 줄 — 좌측 라인 + 마디 + 우측 컨텐츠.
struct SpineNodeRow: View {
    let day: Day
    var loader: ThumbnailLoader
    var isFirst: Bool
    var isLast: Bool

    /// nil이 아닌 사진의 favorite만 (Day 내부, capturedAt asc).
    private var favoritePhotos: [Photo] {
        day.photos.filter { $0.isFavorite }.sorted { $0.capturedAt < $1.capturedAt }
    }

    private var nodeSize: CGFloat {
        SpineNodeSizing.size(forFavoriteCount: favoritePhotos.count)
    }

    private var isUntidy: Bool {
        favoritePhotos.isEmpty
    }

    private var nodeColor: Color {
        isUntidy ? TripsColor.border : TripsColor.accent
    }

    private let spineColumnWidth: CGFloat = 56
    private let lineWidth: CGFloat = 3

    var body: some View {
        HStack(alignment: .top, spacing: TripsSpacing.l) {
            spineColumn
            content
        }
        .padding(.horizontal, TripsSpacing.l)
        .padding(.bottom, TripsSpacing.xxl)
    }

    private var spineColumn: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : TripsColor.border)
                .frame(width: lineWidth, height: TripsSpacing.l)
            Circle()
                .fill(nodeColor)
                .frame(width: nodeSize, height: nodeSize)
                .overlay(
                    Circle()
                        .stroke(TripsColor.bg, lineWidth: 2)
                )
            Rectangle()
                .fill(isLast ? Color.clear : TripsColor.border)
                .frame(width: lineWidth)
                .frame(maxHeight: .infinity)
        }
        .frame(width: spineColumnWidth, alignment: .center)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: TripsSpacing.s) {
            Text(formattedDate)
                .font(TripsFont.title)
                .foregroundStyle(isUntidy ? TripsColor.textSecondary : TripsColor.textPrimary)
            if isUntidy {
                untidyHint
            } else {
                photoStrip
            }
        }
        .padding(.top, TripsSpacing.xs)
    }

    private var untidyHint: some View {
        HStack(spacing: TripsSpacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
            Text(String(localized: "spine.unset \(day.photos.count)"))
        }
        .font(TripsFont.captionSmall)
        .foregroundStyle(TripsColor.textSecondary)
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TripsSpacing.m) {
                ForEach(favoritePhotos) { photo in
                    NavigationLink(value: PhotoNavigationTarget.detail(photo)) {
                        PhotoThumbnailView(
                            photo: photo,
                            loader: loader,
                            sideLength: 130,
                            showsSceneBadge: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, TripsSpacing.xs)
        }
    }

    private var formattedDate: String {
        day.date.formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
        )
    }
}
