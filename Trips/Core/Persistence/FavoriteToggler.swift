import Foundation
import SwiftData

/// ♥ 토글 — Photo.isFavorite 반전 + Scene 대표 자동 승격.
/// LOCKED 정책 (`.claude/rules/persistence.md`):
/// - ♥ ON → 즉시 `scene.representativePhoto = photo`
/// - ♥ OFF → `TripImporter.pickRepresentative`로 재선정 (남은 ♥ 우선, 없으면 가장 빠른 capturedAt)
/// - Scene 영향 시 `userModifiedAt = .now` — Rescan에서 보존됨 (7차 라운드)
@MainActor
enum FavoriteToggler {

    static func toggle(photo: Photo, context: ModelContext) throws {
        photo.isFavorite.toggle()

        if let scene = photo.scene {
            scene.representativePhoto = TripImporter.pickRepresentative(from: scene.photos)
            scene.userModifiedAt = .now
        }

        try context.save()
    }
}
