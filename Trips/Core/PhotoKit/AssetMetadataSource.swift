import Foundation
import CoreLocation
import Photos

/// PHAsset에 직접 의존하지 않도록 한 겹 추상화. 어댑터·테스트가 PHAsset 인스턴스를 만들 필요 없이
/// 이 프로토콜을 만족하는 어떤 값이든 받을 수 있게 함.
protocol AssetMetadataSource {
    var localIdentifier: String { get }
    var creationDate: Date? { get }
    var location: CLLocation? { get }
}

extension PHAsset: AssetMetadataSource {}
