import Testing
import Foundation
@testable import Trips

/// B1 LOCKED — 24h / 50km / 10장. 합성 메타데이터로 경계 케이스 검증.
@Suite("TripGrouping (B1)")
struct TripGroupingTests {

    // MARK: - Fixtures

    private let seoul = Coordinate(latitude: 37.5665, longitude: 126.9780)
    private let busan = Coordinate(latitude: 35.1796, longitude: 129.0756)  // 서울에서 약 325km
    private let nearSeoul = Coordinate(latitude: 37.5800, longitude: 126.9900)  // 서울에서 약 2km

    /// 같은 좌표, capturedAt만 균등 분포한 합성 사진 N장.
    private func makePhotos(
        count: Int,
        startingAt: Date,
        intervalSeconds: TimeInterval = 600,  // 10분 간격
        coordinate: Coordinate?
    ) -> [PhotoMetadata] {
        (0..<count).map { i in
            PhotoMetadata(
                assetLocalId: "asset-\(UUID().uuidString.prefix(8))",
                capturedAt: startingAt.addingTimeInterval(Double(i) * intervalSeconds),
                coordinate: coordinate
            )
        }
    }

    // MARK: - Empty / small input

    @Test("빈 입력 → 빈 결과")
    func emptyInput() {
        let result = TripGrouping.group(photos: [], homeAnchor: seoul)
        #expect(result.isEmpty)
    }

    @Test("사진 1장 → 0 trip (10장 미만)")
    func singlePhoto() {
        let photos = makePhotos(count: 1, startingAt: .now, coordinate: busan)
        let result = TripGrouping.group(photos: photos, homeAnchor: seoul)
        #expect(result.isEmpty)
    }

    @Test("9장(임계 1장 부족) → 0 trip")
    func belowMinCount() {
        let photos = makePhotos(count: 9, startingAt: .now, coordinate: busan)
        let result = TripGrouping.group(photos: photos, homeAnchor: seoul)
        #expect(result.isEmpty)
    }

    @Test("정확히 10장(임계) + 멀리 → 1 trip")
    func exactlyMinCount() {
        let photos = makePhotos(count: 10, startingAt: .now, coordinate: busan)
        let result = TripGrouping.group(photos: photos, homeAnchor: seoul)
        #expect(result.count == 1)
        #expect(result[0].photos.count == 10)
    }

    // MARK: - Distance filter

    @Test("10장 + 집 근처(2km) → 0 trip (거리 필터)")
    func nearHomeFiltered() {
        let photos = makePhotos(count: 10, startingAt: .now, coordinate: nearSeoul)
        let result = TripGrouping.group(photos: photos, homeAnchor: seoul)
        #expect(result.isEmpty)
    }

    @Test("10장 + 멀리(부산) → 1 trip")
    func farFromHomeAccepted() {
        let photos = makePhotos(count: 10, startingAt: .now, coordinate: busan)
        let result = TripGrouping.group(photos: photos, homeAnchor: seoul)
        #expect(result.count == 1)
    }

    @Test("homeAnchor nil → 거리 필터 건너뜀, 사진 수만 본다")
    func nilHomeAnchor() {
        let photos = makePhotos(count: 10, startingAt: .now, coordinate: nearSeoul)
        let result = TripGrouping.group(photos: photos, homeAnchor: nil)
        #expect(result.count == 1)
    }

    @Test("homeAnchor 있는데 사진에 좌표 없음 → 거리 검증 실패 → 0 trip")
    func noCoordinateWithHomeAnchor() {
        let photos = makePhotos(count: 10, startingAt: .now, coordinate: nil)
        let result = TripGrouping.group(photos: photos, homeAnchor: seoul)
        #expect(result.isEmpty)
    }

    // MARK: - Time gap split

    @Test("두 묶음을 25h 간격으로 → 2 trip")
    func splitOnTimeGap() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let first = makePhotos(count: 10, startingAt: base, coordinate: busan)
        let secondStart = first.last!.capturedAt.addingTimeInterval(25 * 3600)
        let second = makePhotos(count: 10, startingAt: secondStart, coordinate: busan)
        let result = TripGrouping.group(photos: first + second, homeAnchor: seoul)
        #expect(result.count == 2)
    }

    @Test("정확히 24h 갭 → 두 묶음으로 분할 (>= 24h 규칙)")
    func exactTwentyFourHourGap() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let first = makePhotos(count: 10, startingAt: base, coordinate: busan)
        let secondStart = first.last!.capturedAt.addingTimeInterval(24 * 3600)
        let second = makePhotos(count: 10, startingAt: secondStart, coordinate: busan)
        let result = TripGrouping.group(photos: first + second, homeAnchor: seoul)
        #expect(result.count == 2)
    }

    @Test("23h 59분 갭 → 한 묶음 유지")
    func belowTimeGapMergesAcross() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let first = makePhotos(count: 10, startingAt: base, coordinate: busan)
        let secondStart = first.last!.capturedAt.addingTimeInterval((24 * 3600) - 60)
        let second = makePhotos(count: 10, startingAt: secondStart, coordinate: busan)
        let result = TripGrouping.group(photos: first + second, homeAnchor: seoul)
        #expect(result.count == 1)
        #expect(result[0].photos.count == 20)
    }

    @Test("한쪽이 임계 미달 → 그쪽만 탈락")
    func splitOneSideBelowMin() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let first = makePhotos(count: 10, startingAt: base, coordinate: busan)
        let secondStart = first.last!.capturedAt.addingTimeInterval(25 * 3600)
        let second = makePhotos(count: 5, startingAt: secondStart, coordinate: busan)
        let result = TripGrouping.group(photos: first + second, homeAnchor: seoul)
        #expect(result.count == 1)
        #expect(result[0].photos.count == 10)
    }

    // MARK: - 50km boundary

    @Test("거의 정확히 50km — 약간 멀면 통과")
    func justBeyondFiftyKm() {
        // 서울 기준 약 50.5km 떨어진 좌표 (위도 +0.455 ≈ 50.6km)
        let farPoint = Coordinate(latitude: seoul.latitude + 0.455, longitude: seoul.longitude)
        let photos = makePhotos(count: 10, startingAt: .now, coordinate: farPoint)
        let result = TripGrouping.group(photos: photos, homeAnchor: seoul)
        #expect(result.count == 1)
    }

    @Test("거의 정확히 50km — 약간 가까우면 탈락")
    func justUnderFiftyKm() {
        // 서울 기준 약 49.5km (위도 +0.445)
        let nearPoint = Coordinate(latitude: seoul.latitude + 0.445, longitude: seoul.longitude)
        let photos = makePhotos(count: 10, startingAt: .now, coordinate: nearPoint)
        let result = TripGrouping.group(photos: photos, homeAnchor: seoul)
        #expect(result.isEmpty)
    }

    // MARK: - Input ordering robustness

    @Test("입력 순서가 뒤죽박죽이어도 결과 같다")
    func unsortedInputProducesSameResult() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = makePhotos(count: 10, startingAt: base, coordinate: busan)
        let shuffled = sorted.shuffled()
        let a = TripGrouping.group(photos: sorted, homeAnchor: seoul)
        let b = TripGrouping.group(photos: shuffled, homeAnchor: seoul)
        #expect(a.count == b.count)
        #expect(a.first?.photos.count == b.first?.photos.count)
    }

    // MARK: - Centroid

    @Test("centroid는 좌표 있는 사진들의 평균")
    func centroidAverages() {
        let p1 = PhotoMetadata(
            assetLocalId: "a",
            capturedAt: .now,
            coordinate: Coordinate(latitude: 0, longitude: 0)
        )
        let p2 = PhotoMetadata(
            assetLocalId: "b",
            capturedAt: .now,
            coordinate: Coordinate(latitude: 10, longitude: 20)
        )
        let candidate = TripCandidate(photos: [p1, p2])
        let centroid = candidate.centroid
        #expect(centroid?.latitude == 5)
        #expect(centroid?.longitude == 10)
    }
}
