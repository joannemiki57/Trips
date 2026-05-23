import Testing
import Foundation
@testable import Trips

/// `TripLocationNamer.name(from:)`은 CLPlacemark에서 추출한 3개 컴포넌트 중
/// locality → administrativeArea → country 순으로 첫 번째 non-nil을 고른다.
@Suite("TripLocationNamer · name picker")
struct TripLocationNamerTests {

    @Test("locality 있으면 그걸 사용")
    func usesLocalityWhenAvailable() {
        let components = PlaceComponents(
            locality: "Seoul",
            administrativeArea: "Seoul",
            country: "South Korea"
        )
        #expect(TripLocationNamer.name(from: components) == "Seoul")
    }

    @Test("locality 없으면 administrativeArea")
    func fallsBackToAdministrativeArea() {
        let components = PlaceComponents(
            locality: nil,
            administrativeArea: "Jeju",
            country: "South Korea"
        )
        #expect(TripLocationNamer.name(from: components) == "Jeju")
    }

    @Test("locality·admin 둘 다 없으면 country")
    func fallsBackToCountry() {
        let components = PlaceComponents(
            locality: nil,
            administrativeArea: nil,
            country: "Japan"
        )
        #expect(TripLocationNamer.name(from: components) == "Japan")
    }

    @Test("모두 nil이면 nil")
    func allNilReturnsNil() {
        let components = PlaceComponents(
            locality: nil,
            administrativeArea: nil,
            country: nil
        )
        #expect(TripLocationNamer.name(from: components) == nil)
    }

    @Test("locality가 빈 문자열이면 다음 단계로 폴백")
    func emptyLocalityFallsThrough() {
        let components = PlaceComponents(
            locality: "",
            administrativeArea: "Hokkaido",
            country: "Japan"
        )
        #expect(TripLocationNamer.name(from: components) == "Hokkaido")
    }

    @Test("administrativeArea도 빈 문자열이면 country까지 폴백")
    func emptyAdminFallsThrough() {
        let components = PlaceComponents(
            locality: "",
            administrativeArea: "",
            country: "France"
        )
        #expect(TripLocationNamer.name(from: components) == "France")
    }
}
