import Foundation
import SwiftData

/// Scene 분리 — ClusterView의 "Scene에서 빼기" 액션이 호출.
/// 정책:
/// - 사진 한 장을 그 사진의 Scene에서 떼어낸다 (`photo.scene = nil`)
/// - 남은 Scene 멤버가 < 2장이면 Scene 자체를 삭제 (`UserSettings.showSinglePhotoAsScene` 기본 OFF)
/// - Scene이 유지되면 대표 재선정 + `userModifiedAt = .now`
/// - photo.scene이 이미 nil이면 no-op
@MainActor
enum SceneSplitter {

    static func split(
        photo: Photo,
        context: ModelContext
    ) throws {
        guard let scene = photo.scene else { return }
        photo.scene = nil

        let remaining = scene.photos
        if remaining.count < 2 {
            // 남은 사진이 0~1장이면 Scene 폐기 (남은 1장은 단독 Photo로 회귀).
            context.delete(scene)
        } else {
            scene.representativePhoto = TripImporter.pickRepresentative(from: remaining)
            scene.userModifiedAt = .now
        }
        try context.save()
    }
}
