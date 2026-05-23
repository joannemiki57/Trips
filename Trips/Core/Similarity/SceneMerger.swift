import Foundation
import SwiftData

/// 사용자가 DayFeed에서 사진을 드래그해 다른 사진/그룹 위에 놓을 때 호출되는 병합 로직.
/// 단일 진입점 — UI는 source assetLocalId + target Photo + ModelContext만 넘긴다.
///
/// 정책:
/// - 같은 사진/같은 Scene 드래그는 no-op
/// - target에 Scene이 있으면 destination = target.scene
/// - 아니면 source에 Scene이 있으면 destination = source.scene
/// - 둘 다 없으면 target.day에 새 Scene 생성
/// - source의 기존 Scene은 멤버가 모두 옮겨진 후 삭제
/// - 병합 후 대표는 `TripImporter.pickRepresentative` (♥ 우선, 없으면 가장 빠른 capturedAt)
@MainActor
enum SceneMerger {

    static func merge(
        sourceAssetId: String,
        targetPhoto: Photo,
        context: ModelContext
    ) throws {
        guard sourceAssetId != targetPhoto.assetLocalId else { return }

        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.assetLocalId == sourceAssetId }
        )
        guard let source = try context.fetch(descriptor).first else { return }

        // 같은 Scene 안에서의 드래그는 무시.
        if let srcScene = source.scene,
           let tgtScene = targetPhoto.scene,
           srcScene.persistentModelID == tgtScene.persistentModelID {
            return
        }

        // destination Scene 결정
        let destScene: Scene
        if let existing = targetPhoto.scene {
            destScene = existing
        } else if let existing = source.scene {
            destScene = existing
        } else {
            guard let day = targetPhoto.day else { return }
            destScene = Scene(day: day)
            context.insert(destScene)
        }

        // source의 옛 Scene 멤버를 모두 destScene으로 이동 + 옛 Scene 삭제
        if let sourceScene = source.scene,
           sourceScene.persistentModelID != destScene.persistentModelID {
            let members = Array(sourceScene.photos)
            for photo in members {
                photo.scene = destScene
            }
            context.delete(sourceScene)
        }

        // source/target이 아직 destScene에 없으면 붙임
        if source.scene?.persistentModelID != destScene.persistentModelID {
            source.scene = destScene
        }
        if targetPhoto.scene?.persistentModelID != destScene.persistentModelID {
            targetPhoto.scene = destScene
        }

        destScene.representativePhoto = TripImporter.pickRepresentative(from: destScene.photos)
        destScene.userModifiedAt = .now
        try context.save()
    }
}
