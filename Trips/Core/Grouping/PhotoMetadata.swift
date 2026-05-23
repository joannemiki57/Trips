import Foundation

/// PhotoKit과 결합 전 단위 테스트가 가능하도록 분리된 값 타입.
/// 실제 임포트 시 PHAsset에서 (localIdentifier, creationDate, location, EXIF tz) 추출 후 매핑.
struct PhotoMetadata: Equatable, Hashable, Sendable {
    let assetLocalId: String
    let capturedAt: Date
    let coordinate: Coordinate?
    /// EXIF에서 추출 가능하면 채움. PHAsset만으로는 어려워 W2 EXIF 읽기 단계에서 채움.
    let timeZone: TimeZone?

    init(
        assetLocalId: String,
        capturedAt: Date,
        coordinate: Coordinate?,
        timeZone: TimeZone? = nil
    ) {
        self.assetLocalId = assetLocalId
        self.capturedAt = capturedAt
        self.coordinate = coordinate
        self.timeZone = timeZone
    }
}
