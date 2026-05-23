import Foundation
import Photos
import UIKit

/// C5 LOCKED — PHCachingImageManager 기반 썸네일 로더. 카드 그리드/리스트 셀에서 공유 인스턴스로 사용.
/// 카드별로 새 인스턴스를 만들지 말 것 — 캐시 효과가 사라짐.
@MainActor
@Observable
final class ThumbnailLoader {

    private let manager = PHCachingImageManager()
    private var cache: [CacheKey: UIImage] = [:]

    private struct CacheKey: Hashable {
        let assetLocalId: String
        let widthPx: Int
        let heightPx: Int
    }

    func thumbnail(assetLocalId: String, size: CGSize) async -> UIImage? {
        let scale = UIScreen.main.scale
        let px = CGSize(width: size.width * scale, height: size.height * scale)
        let key = CacheKey(
            assetLocalId: assetLocalId,
            widthPx: Int(px.width),
            heightPx: Int(px.height)
        )
        if let hit = cache[key] {
            return hit
        }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalId], options: nil)
        guard let asset = fetch.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        options.resizeMode = .fast

        let image: UIImage? = await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
            nonisolated(unsafe) var resumed = false
            manager.requestImage(
                for: asset,
                targetSize: px,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if resumed { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                resumed = true
                cont.resume(returning: image)
            }
        }

        if let image {
            cache[key] = image
        }
        return image
    }
}
