import Testing
import Foundation
@testable import Trips

@Suite("Coordinate · Haversine")
struct CoordinateTests {

    @Test("같은 좌표 → 0m")
    func samePoint() {
        let p = Coordinate(latitude: 37.5665, longitude: 126.9780)
        #expect(p.distanceMeters(to: p) == 0)
    }

    @Test("서울 ↔ 부산 ≈ 325km (±2km 허용)")
    func seoulToBusan() {
        let seoul = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let busan = Coordinate(latitude: 35.1796, longitude: 129.0756)
        let d = seoul.distanceMeters(to: busan)
        #expect(d > 323_000)
        #expect(d < 327_000)
    }

    @Test("위도 1° ≈ 111km (±0.5km)")
    func oneDegreeLatitude() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 1, longitude: 0)
        let d = a.distanceMeters(to: b)
        #expect(d > 110_500)
        #expect(d < 111_500)
    }

    @Test("대칭성 — A→B == B→A")
    func symmetry() {
        let a = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let b = Coordinate(latitude: 35.1796, longitude: 129.0756)
        #expect(a.distanceMeters(to: b) == b.distanceMeters(to: a))
    }
}
