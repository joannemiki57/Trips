import SwiftUI
import SwiftData

/// Trip 상세 — 날짜별 사진 그리드 (보조 뷰). mvp.md §6 "Day 섹션 (피드 뷰) — 메인 포토 그리드".
/// 사진 탭 시 ClusterView로 이동. 사진을 길게 눌러 다른 사진 위로 드래그하면 Scene 병합.
/// Visual Spine(기본 뷰)는 W6에서 본격 구현 예정.
struct DayFeedView: View {
    let trip: Trip
    var loader: ThumbnailLoader

    @Environment(\.modelContext) private var context

    @Query(sort: \Label.name)
    private var allLabels: [Label]

    @State private var selectedLabelIds: Set<UUID> = []

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: TripsSpacing.xs)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TripsSpacing.l, pinnedViews: [.sectionHeaders]) {
                if !labelsInTrip.isEmpty {
                    filterBar
                }
                ForEach(sortedDays) { day in
                    Section {
                        gridFor(day: day)
                    } header: {
                        header(for: day)
                    }
                }
            }
            .padding(.horizontal, TripsSpacing.l)
            .padding(.bottom, TripsSpacing.xl)
        }
        .background(TripsColor.bg)
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 이 Trip 안에서 실제로 쓰이는 라벨만 (전역 라벨 풀에서 필터). 한 번도 안 붙은 라벨은 안 보여줌.
    private var labelsInTrip: [Label] {
        let photoLabels = trip.days.flatMap { $0.photos.flatMap(\.allLabels) }
        let unique = Dictionary(grouping: photoLabels) { $0.id }.compactMapValues { $0.first }
        return unique.values.sorted { $0.name < $1.name }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TripsSpacing.s) {
                ForEach(labelsInTrip) { label in
                    Button {
                        toggleFilter(label.id)
                    } label: {
                        Text(label.name)
                            .font(TripsFont.caption.weight(.semibold))
                            .padding(.horizontal, TripsSpacing.m)
                            .padding(.vertical, TripsSpacing.xs)
                            .background(selectedLabelIds.contains(label.id) ? TripsColor.accent : TripsColor.surface)
                            .foregroundStyle(selectedLabelIds.contains(label.id) ? .white : TripsColor.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(TripsColor.border, lineWidth: selectedLabelIds.contains(label.id) ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, TripsSpacing.xs)
        }
    }

    private func toggleFilter(_ id: UUID) {
        if selectedLabelIds.contains(id) {
            selectedLabelIds.remove(id)
        } else {
            selectedLabelIds.insert(id)
        }
    }

    private var sortedDays: [Day] {
        trip.days.sorted { $0.date < $1.date }
    }

    /// Scene에 묶인 사진은 대표 1장만, 안 묶인 사진은 그대로. 시간 오름차순.
    /// 라벨 필터가 활성화된 경우(`selectedLabelIds` non-empty), 각 사진의 `allLabels`에 선택된 라벨이 적어도 하나 있을 때만 통과.
    private func displayablePhotos(in day: Day) -> [Photo] {
        let sorted = day.photos.sorted { $0.capturedAt < $1.capturedAt }
        var result: [Photo] = []
        var seenScenes = Set<UUID>()
        for photo in sorted {
            let passesFilter = selectedLabelIds.isEmpty
                || photo.allLabels.contains(where: { selectedLabelIds.contains($0.id) })
            guard passesFilter else { continue }
            if let scene = photo.scene {
                if seenScenes.contains(scene.id) { continue }
                seenScenes.insert(scene.id)
                result.append(scene.representativePhoto ?? photo)
            } else {
                result.append(photo)
            }
        }
        return result
    }

    private func gridFor(day: Day) -> some View {
        LazyVGrid(columns: columns, spacing: TripsSpacing.xs) {
            ForEach(displayablePhotos(in: day)) { photo in
                NavigationLink(value: navigationTarget(for: photo)) {
                    PhotoThumbnailView(photo: photo, loader: loader, sideLength: 100)
                }
                .buttonStyle(.plain)
                .draggable(photo.assetLocalId)
                .dropDestination(for: String.self) { items, _ in
                    guard let sourceId = items.first else { return false }
                    do {
                        try SceneMerger.merge(
                            sourceAssetId: sourceId,
                            targetPhoto: photo,
                            context: context
                        )
                        return true
                    } catch {
                        return false
                    }
                }
            }
        }
    }

    private func navigationTarget(for photo: Photo) -> PhotoNavigationTarget {
        photo.scene != nil ? .cluster(photo) : .detail(photo)
    }

    private func header(for day: Day) -> some View {
        HStack {
            Text(formattedDate(day.date))
                .font(TripsFont.title)
                .foregroundStyle(TripsColor.textPrimary)
            Spacer()
            Text(String(localized: "dayfeed.photoCount \(day.photos.count)"))
                .font(TripsFont.caption)
                .foregroundStyle(TripsColor.textSecondary)
        }
        .padding(.vertical, TripsSpacing.s)
        .background(TripsColor.bg)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
        )
    }
}
