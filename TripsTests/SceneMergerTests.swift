import Testing
import Foundation
import SwiftData
@testable import Trips

@Suite("SceneMerger · drag-and-drop scene merge")
@MainActor
struct SceneMergerTests {

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

    /// Trip + Day 하나 + Photo N장 시드.
    private func seedDay(ctx: ModelContext, assetIds: [String]) throws -> (Day, [Photo]) {
        let trip = Trip(name: "T", startDate: date(2026, 5, 1), endDate: date(2026, 5, 1))
        ctx.insert(trip)
        let day = Day(date: date(2026, 5, 1), trip: trip)
        ctx.insert(day)
        let photos = assetIds.enumerated().map { (i, id) in
            let p = Photo(day: day, assetLocalId: id, capturedAt: date(2026, 5, 1, 12, i))
            ctx.insert(p)
            return p
        }
        try ctx.save()
        return (day, photos)
    }

    private func makeScene(ctx: ModelContext, day: Day, photos: [Photo]) -> Scene {
        let scene = Scene(day: day)
        ctx.insert(scene)
        for p in photos { p.scene = scene }
        scene.representativePhoto = TripImporter.pickRepresentative(from: photos)
        return scene
    }

    @Test("두 Scene 병합 — target Scene으로 source 전부 이동, source Scene 삭제")
    func mergeTwoScenes() throws {
        let ctx = try freshContext()
        let (day, photos) = try seedDay(ctx: ctx, assetIds: ["a", "b", "c", "d"])
        let sourceScene = makeScene(ctx: ctx, day: day, photos: [photos[0], photos[1]])
        let targetScene = makeScene(ctx: ctx, day: day, photos: [photos[2], photos[3]])
        try ctx.save()

        try SceneMerger.merge(sourceAssetId: "a", targetPhoto: photos[2], context: ctx)

        #expect(targetScene.photos.count == 4)
        #expect(Set(targetScene.photos.map(\.assetLocalId)) == ["a", "b", "c", "d"])
        #expect(targetScene.userModifiedAt != nil)
        let scenes = try ctx.fetch(FetchDescriptor<Scene>())
        #expect(scenes.count == 1)
        #expect(scenes.first?.persistentModelID == targetScene.persistentModelID)
        _ = sourceScene  // 삭제됨
    }

    @Test("단독 사진(no scene)을 Scene에 드롭 → 합류")
    func singlePhotoJoinsTargetScene() throws {
        let ctx = try freshContext()
        let (day, photos) = try seedDay(ctx: ctx, assetIds: ["a", "b", "c"])
        let targetScene = makeScene(ctx: ctx, day: day, photos: [photos[1], photos[2]])
        try ctx.save()

        // a는 scene 없음
        try SceneMerger.merge(sourceAssetId: "a", targetPhoto: photos[1], context: ctx)

        #expect(targetScene.photos.count == 3)
        #expect(photos[0].scene?.persistentModelID == targetScene.persistentModelID)
    }

    @Test("Scene 사진을 단독 사진에 드롭 → 단독이 source Scene에 합류")
    func sceneDroppedOnSinglePhotoJoinsExistingScene() throws {
        let ctx = try freshContext()
        let (day, photos) = try seedDay(ctx: ctx, assetIds: ["a", "b", "c"])
        let sourceScene = makeScene(ctx: ctx, day: day, photos: [photos[0], photos[1]])
        try ctx.save()

        // c는 scene 없음, a는 sourceScene 멤버. a를 c에 드롭
        try SceneMerger.merge(sourceAssetId: "a", targetPhoto: photos[2], context: ctx)

        #expect(sourceScene.photos.count == 3)
        #expect(photos[2].scene?.persistentModelID == sourceScene.persistentModelID)
    }

    @Test("둘 다 단독 → 새 Scene 생성")
    func twoSinglesCreateNewScene() throws {
        let ctx = try freshContext()
        let (_, photos) = try seedDay(ctx: ctx, assetIds: ["a", "b"])
        try ctx.save()

        try SceneMerger.merge(sourceAssetId: "a", targetPhoto: photos[1], context: ctx)

        let scenes = try ctx.fetch(FetchDescriptor<Scene>())
        #expect(scenes.count == 1)
        #expect(scenes.first?.photos.count == 2)
    }

    @Test("같은 Scene 안에서 드래그 → 변경 없음")
    func sameSceneDragIsNoop() throws {
        let ctx = try freshContext()
        let (day, photos) = try seedDay(ctx: ctx, assetIds: ["a", "b", "c"])
        let scene = makeScene(ctx: ctx, day: day, photos: [photos[0], photos[1], photos[2]])
        try ctx.save()

        try SceneMerger.merge(sourceAssetId: "a", targetPhoto: photos[1], context: ctx)

        #expect(scene.photos.count == 3)
        let scenes = try ctx.fetch(FetchDescriptor<Scene>())
        #expect(scenes.count == 1)
    }

    @Test("같은 사진 자기 자신에 드래그 → 변경 없음")
    func selfDragIsNoop() throws {
        let ctx = try freshContext()
        let (day, photos) = try seedDay(ctx: ctx, assetIds: ["a", "b"])
        let scene = makeScene(ctx: ctx, day: day, photos: [photos[0], photos[1]])
        try ctx.save()

        try SceneMerger.merge(sourceAssetId: "a", targetPhoto: photos[0], context: ctx)

        #expect(scene.photos.count == 2)
    }

    @Test("병합 후 대표는 ♥ 우선, 없으면 가장 빠른 capturedAt")
    func representativeReevaluatedAfterMerge() throws {
        let ctx = try freshContext()
        let (day, photos) = try seedDay(ctx: ctx, assetIds: ["a", "b", "c", "d"])
        // a/b는 source, c/d는 target. 둘 중 b만 ♥.
        photos[1].isFavorite = true
        let sourceScene = makeScene(ctx: ctx, day: day, photos: [photos[0], photos[1]])
        let targetScene = makeScene(ctx: ctx, day: day, photos: [photos[2], photos[3]])
        try ctx.save()

        try SceneMerger.merge(sourceAssetId: "a", targetPhoto: photos[2], context: ctx)

        // 합쳐진 Scene의 대표는 b (♥)여야 함
        #expect(targetScene.representativePhoto?.assetLocalId == "b")
        _ = sourceScene
    }
}
