import Foundation
import CoreLocation

/// CLPlacemark에서 뽑아낸 3개 컴포넌트. CLPlacemark는 테스트에서 합성하기 어려워
/// 한 겹 분리해 둔다 — 픽킹 로직만 따로 테스트.
struct PlaceComponents: Equatable, Sendable {
    let locality: String?
    let administrativeArea: String?
    let country: String?

    init(locality: String? = nil, administrativeArea: String? = nil, country: String? = nil) {
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
    }
}

/// Trip centroid 좌표 → rough 위치 이름. CLGeocoder reverse-geocode + locality/admin/country 폴백.
/// 네트워크 실패·결과 없음·좌표 nil 모두 nil 반환 — 호출자는 기본 이름으로 폴백.
enum TripLocationNamer {

    /// 픽킹 로직만 — 빈 문자열은 nil처럼 취급해 다음 단계로.
    static func name(from components: PlaceComponents) -> String? {
        if let value = nonEmpty(components.locality) { return value }
        if let value = nonEmpty(components.administrativeArea) { return value }
        if let value = nonEmpty(components.country) { return value }
        return nil
    }

    /// reverse-geocode 한 번 호출 → PlaceComponents → name. CLGeocoder는 앱당 rate-limit 있으니
    /// 호출자(TripImportService)가 sequential하게 부르는 것을 전제.
    static func name(forCentroid coordinate: Coordinate?) async -> String? {
        guard let coordinate else { return nil }
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let first = placemarks.first else { return nil }
            let components = PlaceComponents(
                locality: first.locality,
                administrativeArea: first.administrativeArea,
                country: first.country
            )
            return name(from: components)
        } catch {
            return nil
        }
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }
}
