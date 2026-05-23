import Foundation
import SwiftData

@Model
final class Scene {
    @Attribute(.unique) var id: UUID
    var representativePhoto: Photo?
    var memo: String?
    var day: Day?

    /// 사용자가 직접 묶기/분리/대표 변경 등으로 Scene을 손댄 시각. nil = 자동 생성된 Scene.
    /// `TripImporter.generateScenes`는 nil이 아닌 Scene과 그 멤버 사진을 보존(B3 재계산 대상에서 제외).
    /// LOCKED 7차 라운드 (2026-05-20).
    var userModifiedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \Photo.scene)
    var photos: [Photo] = []

    @Relationship(inverse: \Label.scenes)
    var labels: [Label] = []

    init(
        id: UUID = UUID(),
        day: Day,
        representativePhoto: Photo? = nil,
        memo: String? = nil,
        userModifiedAt: Date? = nil
    ) {
        self.id = id
        self.day = day
        self.representativePhoto = representativePhoto
        self.memo = memo
        self.userModifiedAt = userModifiedAt
    }
}
