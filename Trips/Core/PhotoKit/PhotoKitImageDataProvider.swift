import Foundation
import Photos

/// `PhotoImageDataProvider` 구현 — PHImageManager로 전체 해상도 이미지 데이터 fetch.
/// PDF export 등 한 번에 다 가져오는 시나리오에 맞춤 (썸네일 캐시 별도 → `ThumbnailLoader`).
struct PhotoKitImageDataProvider: PhotoImageDataProvider {
    private let manager: PHImageManager

    init(manager: PHImageManager = .default()) {
        self.manager = manager
    }

    func data(for photo: Photo) async -> Data? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetLocalId], options: nil)
        guard let asset = fetch.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current

        return await withCheckedContinuation { (cont: CheckedContinuation<Data?, Never>) in
            nonisolated(unsafe) var resumed = false
            manager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if resumed { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                resumed = true
                cont.resume(returning: data)
            }
        }
    }
}
