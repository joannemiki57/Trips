import Testing
import Foundation
import SwiftData
@testable import Trips

@Suite("SceneSplitter · 사진을 Scene에서 분리")
@MainActor
struct SceneSplitterTests {

    private func freshContext() throws -> ModelContext {
        let container = try TripsModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ minute: Int = 0) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        comps.hour = h; comps.minute = minute
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: comps)!
    }

    private func seedScene(ctx: ModelContext, ids: [String]) throws -> (Scene, [Photo]) {
        let trip = Trip(name: "T", startDate: date(2026, 5, 1), endDate: date(2026, 5, 1))
        ctx.insert(trip)
        let day = Day(date: date(2026, 5, 1), trip: trip)
        ctx.insert(day)
        let photos = ids.enumerated().map { (i, id) in
            let p = Photo(day: day, assetLocalId: id, capturedAt: date(2026, 5, 1, 12, i))
            ctx.insert(p)
            return p
        }
        let scene = Scene(day: day)
        ctx.insert(scene)
        for p in photos { p.scene = scene }
        scene.representativePhoto = photos.first
        try ctx.save()
        return (scene, photos)
    }

    @Test("3장 Scene에서 1장 빼기 → 남은 2장 Scene 유지 + 대표 재선정")
    func splitFromThreePhotoScene() throws {
        let ctx = try freshContext()
        let (scene, photos) = try seedScene(ctx: ctx, ids: ["a", "b", "c"])
        // 대표는 처음에 a. b를 분리하고 남은 a, c 중 가장 빠른 = a 유지
        try SceneSplitter.split(photo: photos[1], context: ctx)

        #expect(scene.photos.count == 2)
        #expect(Set(scene.photos.map(\.assetLocalId)) == ["a", "c"])
        #expect(photos[1].scene == nil)
        #expect(scene.representativePhoto?.assetLocalId == "a")
        #expect(scene.userModifiedAt != nil)
    }

    @Test("2장 Scene에서 1장 빼기 → Scene 자체 삭제")
    func splitFromTwoPhotoSceneDeletesScene() throws {
        let ctx = try freshContext()
        let (_, photos) = try seedScene(ctx: ctx, ids: ["a", "b"])

        try SceneSplitter.split(photo: photos[0], context: ctx)

        #expect(photos[0].scene == nil)
        #expect(photos[1].scene == nil)
        let scenes = try ctx.fetch(FetchDescriptor<Scene>())
        #expect(scenes.isEmpty)
    }

    @Test("대표 사진을 빼면 남은 사진 중 가장 빠른 것으로 대표 재선정")
    func splittingRepresentativeRepicksRepresentative() throws {
        let ctx = try freshContext()
        let (scene, photos) = try seedScene(ctx: ctx, ids: ["a", "b", "c"])
        // 대표 = a. a를 빼면 b가 새 대표 (둘 중 더 빠른 capturedAt).
        try SceneSplitter.split(photo: photos[0], context: ctx)

        #expect(scene.representativePhoto?.assetLocalId == "b")
    }

    @Test("scene이 nil인 사진을 split → no-op (에러 없음)")
    func splittingSinglePhotoIsNoop() throws {
        let ctx = try freshContext()
        let trip = Trip(name: "T", startDate: date(2026, 5, 1), endDate: date(2026, 5, 1))
        ctx.insert(trip)
        let day = Day(date: date(2026, 5, 1), trip: trip)
        ctx.insert(day)
        let lonePhoto = Photo(day: day, assetLocalId: "x", capturedAt: date(2026, 5, 1))
        ctx.insert(lonePhoto)
        try ctx.save()

        try SceneSplitter.split(photo: lonePhoto, context: ctx)

        #expect(lonePhoto.scene == nil)
    }
}
