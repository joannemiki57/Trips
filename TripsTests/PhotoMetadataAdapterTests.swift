import Testing
import Foundation
import CoreLocation
@testable import Trips

/// `AssetMetadataSource` 프로토콜 덕에 PHAsset 인스턴스를 만들지 않고도 어댑터를 단위 테스트할 수 있음.
@Suite("PhotoMetadataAdapter")
struct PhotoMetadataAdapterTests {

    private struct MockAsset: AssetMetadataSource {
        let localIdentifier: String
        let creationDate: Date?
        let location: CLLocation?
    }

    @Test("creationDate가 nil이면 nil 반환")
    func dropsAssetsWithoutCreationDate() {
        let mock = MockAsset(
            localIdentifier: "asset-1",
            creationDate: nil,
            location: CLLocation(latitude: 37, longitude: 127)
        )
        #expect(PhotoMetadataAdapter.from(mock) == nil)
    }

    @Test("location nil → coordinate nil로 전달")
    func mapsMissingLocationToNil() {
        let now = Date()
        let mock = MockAsset(
            localIdentifier: "asset-2",
            creationDate: now,
            location: nil
        )
        let result = PhotoMetadataAdapter.from(mock)
        #expect(result?.assetLocalId == "asset-2")
        #expect(result?.capturedAt == now)
        #expect(result?.coordinate == nil)
    }

    @Test("location 있음 → Coordinate로 매핑")
    func mapsLocationToCoordinate() {
        let now = Date()
        let mock = MockAsset(
            localIdentifier: "asset-3",
            creationDate: now,
            location: CLLocation(latitude: 37.5665, longitude: 126.9780)
        )
        let result = PhotoMetadataAdapter.from(mock)
        #expect(result?.coordinate?.latitude == 37.5665)
        #expect(result?.coordinate?.longitude == 126.9780)
    }

    @Test("localIdentifier 그대로 전달")
    func preservesLocalIdentifier() {
        let mock = MockAsset(
            localIdentifier: "F8B9C0D1-1234-5678-90AB-CDEF12345678/L0/001",
            creationDate: Date(),
            location: nil
        )
        let result = PhotoMetadataAdapter.from(mock)
        #expect(result?.assetLocalId == "F8B9C0D1-1234-5678-90AB-CDEF12345678/L0/001")
    }
}
