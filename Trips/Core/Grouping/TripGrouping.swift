import Foundation

/// B1 — Trip 자동 그루핑. selection.md §G LOCKED (2026-05-20):
/// - 시간 갭 ≥ 24h → 새 trip 후보
/// - 군집 중심이 home에서 ≥ 50km 떨어졌을 때만 trip으로 승격
/// - 최소 사진 수 ≥ 10
enum TripGrouping {
    struct Thresholds: Equatable, Sendable {
        let timeGap: TimeInterval
        let minDistanceFromHome: Double
        let minPhotoCount: Int

        static let locked = Thresholds(
            timeGap: 24 * 60 * 60,
            minDistanceFromHome: 50_000,
            minPhotoCount: 10
        )
    }

    /// `homeAnchor`가 nil이면 거리 필터를 건너뛰고 사진 수만 본다 (초기 인덱싱 케이스).
    /// 입력 photos는 사전 정렬 여부와 무관 — 함수 내부에서 capturedAt asc로 정렬.
    static func group(
        photos: [PhotoMetadata],
        homeAnchor: Coordinate?,
        thresholds: Thresholds = .locked
    ) -> [TripCandidate] {
        guard !photos.isEmpty else { return [] }

        let sorted = photos.sorted { $0.capturedAt < $1.capturedAt }

        var clusters: [[PhotoMetadata]] = []
        var current: [PhotoMetadata] = []

        for (idx, photo) in sorted.enumerated() {
            if idx == 0 {
                current = [photo]
                continue
            }
            let prev = sorted[idx - 1]
            let gap = photo.capturedAt.timeIntervalSince(prev.capturedAt)
            if gap >= thresholds.timeGap {
                clusters.append(current)
                current = [photo]
            } else {
                current.append(photo)
            }
        }
        clusters.append(current)

        return clusters.compactMap { cluster -> TripCandidate? in
            guard cluster.count >= thresholds.minPhotoCount else { return nil }
            let candidate = TripCandidate(photos: cluster)
            if let home = homeAnchor {
                guard let centroid = candidate.centroid else {
                    return nil
                }
                guard centroid.distanceMeters(to: home) >= thresholds.minDistanceFromHome else {
                    return nil
                }
            }
            return candidate
        }
    }
}
