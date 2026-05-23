import Foundation

/// B3 — 같은 장면 사진 묶음. selection.md §B + algorithms.md LOCKED:
/// - featureprint distance ≤ T  AND  shot interval ≤ 5min  AND  GPS ≤ 50m (모두 AND)
/// - DBSCAN·pHash 단독·하이브리드는 v1.5+ (금지)
/// - 자동 삭제 없음 — UI는 묶음만 표시
///
/// 본 모듈은 순수 함수: 입력 메타데이터 + featureprint 거리 closure만 받음.
/// Vision API 호출은 `VisionFeaturePrintExtractor`가 담당.
enum SceneGrouping {

    struct Thresholds: Equatable, Sendable {
        let timeInterval: TimeInterval
        let distance: Double
        let featurePrintDistance: Float

        /// `T = 0.4`는 placeholder. Phase 1 PoC 사진 세트로 튜닝.
        static let locked = Thresholds(
            timeInterval: 5 * 60,
            distance: 50,
            featurePrintDistance: 0.4  // TODO(poc): tune T with real photo set
        )
    }

    /// 입력 photos는 정렬 여부와 무관. 결과는 Scene 시작 시간 오름차순.
    /// 각 Scene의 photos는 capturedAt 오름차순.
    /// **GPS 옵셔널 규칙 (6차 라운드 2026-05-20)** — 두 사진 모두 좌표가 있으면 ≤ 50m 검사, 한쪽이라도 없으면 GPS 조건 스킵 (시간 + featureprint만으로 판정).
    static func group(
        photos: [PhotoMetadata],
        featurePrintDistance: (PhotoMetadata, PhotoMetadata) -> Float,
        thresholds: Thresholds = .locked
    ) -> [[PhotoMetadata]] {
        guard !photos.isEmpty else { return [] }
        let sorted = photos.sorted { $0.capturedAt < $1.capturedAt }
        let n = sorted.count

        // Union-find on indices.
        var parent = Array(0..<n)
        func find(_ i: Int) -> Int {
            var i = i
            while parent[i] != i {
                parent[i] = parent[parent[i]]
                i = parent[i]
            }
            return i
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for i in 0..<n {
            for j in (i + 1)..<n {
                if sameScene(sorted[i], sorted[j], thresholds: thresholds, featurePrintDistance: featurePrintDistance) {
                    union(i, j)
                }
            }
        }

        var buckets: [Int: [PhotoMetadata]] = [:]
        for i in 0..<n {
            buckets[find(i), default: []].append(sorted[i])
        }

        return buckets.values
            .map { $0.sorted { $0.capturedAt < $1.capturedAt } }
            .sorted { ($0.first?.capturedAt ?? .distantPast) < ($1.first?.capturedAt ?? .distantPast) }
    }

    /// 두 메타데이터가 같은 Scene인지 결정. AND 규칙 + GPS 옵셔널 (6차 라운드).
    private static func sameScene(
        _ a: PhotoMetadata,
        _ b: PhotoMetadata,
        thresholds: Thresholds,
        featurePrintDistance: (PhotoMetadata, PhotoMetadata) -> Float
    ) -> Bool {
        let timeGap = abs(a.capturedAt.timeIntervalSince(b.capturedAt))
        guard timeGap <= thresholds.timeInterval else { return false }

        // GPS 옵셔널 — 둘 다 좌표 있을 때만 거리 검사. 한쪽이라도 nil이면 스킵 (B3 보조 신호).
        if let coordA = a.coordinate, let coordB = b.coordinate {
            guard coordA.distanceMeters(to: coordB) <= thresholds.distance else { return false }
        }

        return featurePrintDistance(a, b) <= thresholds.featurePrintDistance
    }
}
