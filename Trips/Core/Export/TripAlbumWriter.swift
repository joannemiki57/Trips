import Foundation
import Photos

/// Trip favorite을 카메라롤(사진 앱)의 별도 앨범으로 모으기.
/// mvp.md §5.5 "카메라롤 저장 (인스타 업로드 워크플로우용)".
/// 원본 사진을 복사하는 게 아니라 PHAssetCollection(앨범)에 reference만 추가.
///
/// 구조 메모: SwiftData 모델 읽기는 MainActor 필수 / PhotoKit `performChanges` 클로저는
/// PhotoKit 내부 큐에서 실행 → MainActor 격리 상속하면 안 됨. 진입점만 MainActor,
/// 실제 PhotoKit 작업은 nonisolated 헬퍼.
enum TripAlbumWriter {
    enum WriteError: Error {
        case noFavorites
        case writeAccessDenied
        case writeFailed(String)
    }

    /// 앨범 이름은 Trip 이름을 그대로 사용. 같은 이름 앨범이 이미 있으면 거기에 append.
    /// 진입 게이트(`PhotoPermissionGate`)가 이미 `.readWrite`를 보장하므로 별도 권한 요청 없음.
    @MainActor
    static func saveFavorites(trip: Trip) async throws {
        let assetIds = trip.days
            .flatMap { $0.photos }
            .filter { $0.isFavorite }
            .map { $0.assetLocalId }
        guard !assetIds.isEmpty else { throw WriteError.noFavorites }

        try await performSave(assetIds: assetIds, albumName: trip.name)
    }

    // MARK: - Nonisolated PhotoKit work (Sendable inputs only)

    private static func performSave(assetIds: [String], albumName: String) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            break
        default:
            throw WriteError.writeAccessDenied
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
        guard assets.count > 0 else {
            throw WriteError.writeFailed("assets-not-found")
        }

        let collection = try await findOrCreateAlbum(named: albumName)
        try await addAssets(assets, to: collection)
    }

    private static func findOrCreateAlbum(named name: String) async throws -> PHAssetCollection {
        if let existing = fetchAlbum(named: name) {
            return existing
        }
        let box = PlaceholderBox()
        try await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            box.value = req.placeholderForCreatedAssetCollection
        }
        guard let id = box.value?.localIdentifier,
              let created = fetchAlbum(byLocalIdentifier: id) else {
            throw WriteError.writeFailed("album-create-failed")
        }
        return created
    }

    private static func fetchAlbum(named name: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", name)
        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: options
        )
        return result.firstObject
    }

    private static func fetchAlbum(byLocalIdentifier id: String) -> PHAssetCollection? {
        let result = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [id],
            options: nil
        )
        return result.firstObject
    }

    private static func addAssets(_ assets: PHFetchResult<PHAsset>, to collection: PHAssetCollection) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            guard let req = PHAssetCollectionChangeRequest(for: collection) else { return }
            req.addAssets(assets)
        }
    }

    /// PhotoKit 내부 큐에서 실행되는 sendable 클로저가 외부 var에 직접 쓰지 못하므로 reference 박스.
    private final class PlaceholderBox: @unchecked Sendable {
        var value: PHObjectPlaceholder?
    }
}
