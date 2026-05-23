import Foundation

/// B1 알고리즘 결과 — 영속화 전 후보. 사용자가 수동으로 합치기/나누기 한 결과를
/// 거친 후에야 `Trip` @Model 인스턴스로 변환된다.
struct TripCandidate: Equatable, Sendable {
    let photos: [PhotoMetadata]

    var startDate: Date {
        photos.first?.capturedAt ?? .distantPast
    }

    var endDate: Date {
        photos.last?.capturedAt ?? .distantFuture
    }

    /// GPS가 있는 사진들의 평균 좌표. 좌표 없는 사진만 있으면 nil.
    var centroid: Coordinate? {
        let coords = photos.compactMap(\.coordinate)
        guard !coords.isEmpty else { return nil }
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return Coordinate(latitude: lat, longitude: lon)
    }
}
