import Foundation

struct Coordinate: Equatable, Hashable, Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

extension Coordinate {
    /// Great-circle distance in meters (Haversine).
    func distanceMeters(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let phi1 = latitude * .pi / 180
        let phi2 = other.latitude * .pi / 180
        let deltaPhi = (other.latitude - latitude) * .pi / 180
        let deltaLambda = (other.longitude - longitude) * .pi / 180

        let sinHalfPhi = sin(deltaPhi / 2)
        let sinHalfLambda = sin(deltaLambda / 2)
        let a = sinHalfPhi * sinHalfPhi
            + cos(phi1) * cos(phi2) * sinHalfLambda * sinHalfLambda
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
