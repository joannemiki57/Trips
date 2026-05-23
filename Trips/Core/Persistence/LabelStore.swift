import Foundation
import SwiftData

/// 라벨 CRUD + attach/detach 단일 진입점. UI 코드는 SwiftData 모델을 직접 만지지 않고 이 헬퍼를 통한다.
///
/// 정책:
/// - 이름은 case-insensitive + 양끝 공백 제거 후 비교 — `findOrCreate("Food") == findOrCreate("food")`
/// - 빈 이름·공백만은 `Error.emptyName` 던짐
/// - `Source` 기본 `.userDefined` (사용자가 만든 것). `.builtIn` 시드는 향후 v1 출시 직전.
@MainActor
enum LabelStore {

    enum Error: Swift.Error {
        case emptyName
    }

    static func findOrCreate(
        name: String,
        source: LabelSource = .userDefined,
        context: ModelContext
    ) throws -> Label {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Error.emptyName }

        let needle = trimmed.lowercased()
        let descriptor = FetchDescriptor<Label>()
        let all = try context.fetch(descriptor)
        if let existing = all.first(where: { $0.name.lowercased() == needle }) {
            return existing
        }
        let new = Label(name: trimmed, source: source)
        context.insert(new)
        try context.save()
        return new
    }

    static func attach(label: Label, to photo: Photo, context: ModelContext) throws {
        guard !photo.labels.contains(where: { $0.persistentModelID == label.persistentModelID }) else { return }
        photo.labels.append(label)
        try context.save()
    }

    static func detach(label: Label, from photo: Photo, context: ModelContext) throws {
        photo.labels.removeAll { $0.persistentModelID == label.persistentModelID }
        try context.save()
    }

    static func attach(label: Label, to scene: Scene, context: ModelContext) throws {
        guard !scene.labels.contains(where: { $0.persistentModelID == label.persistentModelID }) else { return }
        scene.labels.append(label)
        scene.userModifiedAt = .now
        try context.save()
    }

    static func detach(label: Label, from scene: Scene, context: ModelContext) throws {
        scene.labels.removeAll { $0.persistentModelID == label.persistentModelID }
        scene.userModifiedAt = .now
        try context.save()
    }
}
