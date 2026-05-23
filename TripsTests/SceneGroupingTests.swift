import Testing
import Foundation
@testable import Trips

/// B3 — featureprint distance ≤ T AND interval ≤ 5min AND GPS ≤ 50m (모두 AND).
/// 모든 케이스는 합성 PhotoMetadata + 주입된 featurePrintDistance closure로 검증한다.
@Suite("SceneGrouping (B3)")
struct SceneGroupingTests {

    private let baseTime = Date(timeIntervalSince1970: 1_700_000_000)
    private let seoul = Coordinate(latitude: 37.5665, longitude: 126.9780)

    private func photo(
        id: String,
        offsetSeconds: TimeInterval = 0,
        coordinate: Coordinate? = nil
    ) -> PhotoMetadata {
        PhotoMetadata(
            assetLocalId: id,
            capturedAt: baseTime.addingTimeInterval(offsetSeconds),
            coordinate: coordinate
        )
    }

    /// 모든 페어를 같다고 응답하는 distance closure (= 0).
    private let allSame: (PhotoMetadata, PhotoMetadata) -> Float = { _, _ in 0 }
    /// 모든 페어를 다르다고 응답 (= 1.0).
    private let allDifferent: (PhotoMetadata, PhotoMetadata) -> Float = { _, _ in 1.0 }

    // MARK: - 기본

    @Test("빈 입력 → 빈 결과")
    func emptyInput() {
        #expect(SceneGrouping.group(photos: [], featurePrintDistance: allSame).isEmpty)
    }

    @Test("사진 1장 → 1 Scene")
    func singlePhoto() {
        let p = photo(id: "a", coordinate: seoul)
        let result = SceneGrouping.group(photos: [p], featurePrintDistance: allSame)
        #expect(result.count == 1)
        #expect(result[0].map(\.assetLocalId) == ["a"])
    }

    @Test("모든 조건 만족 → 1 Scene")
    func allConditionsMet() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 60, coordinate: seoul)
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: allSame)
        #expect(result.count == 1)
        #expect(Set(result[0].map(\.assetLocalId)) == ["a", "b"])
    }

    // MARK: - 각 축 경계

    @Test("시간 갭 정확히 5분 → 같은 Scene")
    func exactlyFiveMinutes() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 5 * 60, coordinate: seoul)
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: allSame)
        #expect(result.count == 1)
    }

    @Test("시간 갭 5분 1초 → 다른 Scene")
    func justOverFiveMinutes() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 5 * 60 + 1, coordinate: seoul)
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: allSame)
        #expect(result.count == 2)
    }

    @Test("GPS 거리 ≈44m (50m 이내) → 같은 Scene")
    func withinFiftyMeters() {
        // 위도 0.0004° ≈ 44.4m (Haversine, R=6371km 기준)
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(
            id: "b",
            offsetSeconds: 60,
            coordinate: Coordinate(latitude: seoul.latitude + 0.0004, longitude: seoul.longitude)
        )
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: allSame)
        #expect(result.count == 1)
    }

    @Test("GPS 거리 1km → 다른 Scene")
    func oneKmApart() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(
            id: "b",
            offsetSeconds: 60,
            coordinate: Coordinate(latitude: seoul.latitude + 0.01, longitude: seoul.longitude)
        )
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: allSame)
        #expect(result.count == 2)
    }

    @Test("Featureprint 거리 정확히 T → 같은 Scene")
    func exactlyAtThresholdT() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 60, coordinate: seoul)
        let t = SceneGrouping.Thresholds.locked.featurePrintDistance
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: { _, _ in t })
        #expect(result.count == 1)
    }

    @Test("Featureprint 거리 T 초과 → 다른 Scene")
    func aboveThresholdT() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 60, coordinate: seoul)
        let t = SceneGrouping.Thresholds.locked.featurePrintDistance
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: { _, _ in t + 0.01 })
        #expect(result.count == 2)
    }

    // MARK: - Union-find (전이성)

    @Test("A~B, B~C, A!~C → 1 Scene (transitive union)")
    func transitiveUnion() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 60, coordinate: seoul)
        let c = photo(id: "c", offsetSeconds: 120, coordinate: seoul)
        // a-c는 featureprint 멀게, a-b·b-c는 가깝게
        let dist: (PhotoMetadata, PhotoMetadata) -> Float = { x, y in
            let pair = Set([x.assetLocalId, y.assetLocalId])
            if pair == ["a", "c"] { return 1.0 }
            return 0
        }
        let result = SceneGrouping.group(photos: [a, b, c], featurePrintDistance: dist)
        #expect(result.count == 1)
        #expect(Set(result[0].map(\.assetLocalId)) == ["a", "b", "c"])
    }

    @Test("두 클러스터 (3+2) → 2 Scenes")
    func twoSeparateClusters() {
        let photos = (0..<5).map { i in
            photo(id: "p\(i)", offsetSeconds: TimeInterval(i) * 60, coordinate: seoul)
        }
        // 0,1,2는 같은 군집 / 3,4는 같은 군집 / 군집 사이는 멀다고 답하기
        let dist: (PhotoMetadata, PhotoMetadata) -> Float = { x, y in
            let i = Int(x.assetLocalId.dropFirst())!
            let j = Int(y.assetLocalId.dropFirst())!
            if (i < 3 && j < 3) || (i >= 3 && j >= 3) { return 0 }
            return 1.0
        }
        let result = SceneGrouping.group(photos: photos, featurePrintDistance: dist)
        #expect(result.count == 2)
        let sizes = result.map(\.count).sorted()
        #expect(sizes == [2, 3])
    }

    // MARK: - GPS 옵셔널 처리 (6차 라운드 2026-05-20 — 한쪽 없으면 GPS 조건 스킵)

    @Test("한쪽 GPS 없음 → GPS 스킵, 시간+featureprint로 같은 Scene 가능")
    func oneSideNoGPSStillGroups() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 60, coordinate: nil)
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: allSame)
        #expect(result.count == 1)
    }

    @Test("둘 다 GPS 없음 → GPS 스킵, 같은 Scene")
    func bothNoGPSStillGroup() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: nil)
        let b = photo(id: "b", offsetSeconds: 60, coordinate: nil)
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: allSame)
        #expect(result.count == 1)
    }

    @Test("한쪽 GPS 없음 + featureprint 멀다 → 여전히 다른 Scene")
    func oneSideNoGPSStillSplitsOnFeaturePrint() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 60, coordinate: nil)
        let result = SceneGrouping.group(photos: [a, b], featurePrintDistance: allDifferent)
        #expect(result.count == 2)
    }

    // MARK: - 순서 무관

    @Test("입력 순서 뒤집어도 결과 동등")
    func inputOrderDoesNotMatter() {
        let a = photo(id: "a", offsetSeconds: 0, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 60, coordinate: seoul)
        let c = photo(id: "c", offsetSeconds: 120, coordinate: seoul)
        let r1 = SceneGrouping.group(photos: [a, b, c], featurePrintDistance: allSame)
        let r2 = SceneGrouping.group(photos: [c, a, b], featurePrintDistance: allSame)
        #expect(r1.count == r2.count)
        let ids1 = Set(r1.flatMap { $0.map(\.assetLocalId) })
        let ids2 = Set(r2.flatMap { $0.map(\.assetLocalId) })
        #expect(ids1 == ids2)
    }

    @Test("출력 Scene은 시작 시간 오름차순")
    func outputSortedByStartTime() {
        let photos = (0..<6).map { i in
            photo(id: "p\(i)", offsetSeconds: TimeInterval(i) * 600, coordinate: seoul)
        }
        // 모두 다른 scene이 되도록 시간 갭 크게 (10분씩) — 5분 초과
        let result = SceneGrouping.group(photos: photos, featurePrintDistance: allSame)
        #expect(result.count == 6)
        let starts = result.map { $0.first!.capturedAt }
        #expect(starts == starts.sorted())
    }

    @Test("Scene 내 photos는 capturedAt 오름차순")
    func photosWithinSceneSorted() {
        let a = photo(id: "a", offsetSeconds: 120, coordinate: seoul)
        let b = photo(id: "b", offsetSeconds: 0, coordinate: seoul)
        let c = photo(id: "c", offsetSeconds: 60, coordinate: seoul)
        let result = SceneGrouping.group(photos: [a, b, c], featurePrintDistance: allSame)
        #expect(result.count == 1)
        #expect(result[0].map(\.assetLocalId) == ["b", "c", "a"])
    }

    @Test("모두 다르다고 응답 → 모두 단독 Scene")
    func everyoneSeparate() {
        let photos = (0..<5).map { i in
            photo(id: "p\(i)", offsetSeconds: TimeInterval(i) * 60, coordinate: seoul)
        }
        let result = SceneGrouping.group(photos: photos, featurePrintDistance: allDifferent)
        #expect(result.count == 5)
        #expect(result.allSatisfy { $0.count == 1 })
    }
}
