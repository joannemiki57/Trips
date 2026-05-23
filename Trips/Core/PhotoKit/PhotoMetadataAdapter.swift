import Foundation
import CoreLocation
import ImageIO
import Photos

/// `PHAsset` 또는 합성 fixture → `PhotoMetadata`. `creationDate`가 nil인 자산은 nil 반환 —
/// B1 알고리즘은 capturedAt 없는 사진을 처리할 수 없음.
enum PhotoMetadataAdapter {

    /// 일반 추상화 경로 — 테스트 fixture가 timeZone을 명시적으로 채워서 넘기는 형태.
    static func from(_ source: AssetMetadataSource, timeZone: TimeZone? = nil) -> PhotoMetadata? {
        guard let captured = source.creationDate else { return nil }
        let coordinate: Coordinate? = source.location.map {
            Coordinate(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude
            )
        }
        return PhotoMetadata(
            assetLocalId: source.localIdentifier,
            capturedAt: captured,
            coordinate: coordinate,
            timeZone: timeZone
        )
    }

    /// PHAsset 전용 경로 — EXIF `OffsetTimeOriginal`을 동기 읽어 `timeZone`을 채운다.
    /// EXIF가 없거나 형식이 어긋나면 nil — DaySplit이 디바이스 tz 폴백을 적용 (B2 잠긴 결정 트리).
    static func from(asset: PHAsset) -> PhotoMetadata? {
        from(asset, timeZone: exifTimeZone(of: asset))
    }

    /// 사진 자산 전체를 capturedAt asc로 스트리밍.
    /// C5 LOCKED — 진보된 chunked/background 인덱싱은 W2 작업. 현재는 enumerate 기반 단일 패스.
    static func streamAllImages() -> AsyncStream<PhotoMetadata> {
        AsyncStream { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options = PHFetchOptions()
                options.sortDescriptors = [
                    NSSortDescriptor(key: "creationDate", ascending: true)
                ]
                let result = PHAsset.fetchAssets(with: .image, options: options)
                result.enumerateObjects { asset, _, _ in
                    if let metadata = Self.from(asset: asset) {
                        continuation.yield(metadata)
                    }
                }
                continuation.finish()
            }
        }
    }

    /// 단일 PHAsset에서 EXIF tz를 동기 읽기. 백그라운드 큐에서 호출되는 것을 전제.
    /// 네트워크(아이클라우드) 다운로드는 비활성 — 로컬 캐시 없으면 nil.
    private static func exifTimeZone(of asset: PHAsset) -> TimeZone? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat

        var foundTimeZone: TimeZone?
        PHImageManager.default().requestImageDataAndOrientation(
            for: asset,
            options: options
        ) { data, _, _, _ in
            guard let data,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                  let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
                return
            }
            let offset = (exif[kCGImagePropertyExifOffsetTimeOriginal as String] as? String)
                ?? (exif[kCGImagePropertyExifOffsetTime as String] as? String)
            foundTimeZone = ExifTimeZone.parse(offsetString: offset)
        }
        return foundTimeZone
    }
}
