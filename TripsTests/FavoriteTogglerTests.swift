import Testing
import Foundation
import SwiftData
@testable import Trips

@Suite("FavoriteToggler · ♥ 토글 + Scene 대표 자동 승격")
@MainActor
struct FavoriteTogglerTests {

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

    @Test("♥ ON — 즉시 Scene 대표로 승격")
    func turningOnFavoritePromotesToRepresentative() throws {
        let ctx = try freshContext()
        let (scene, photos) = try seedScene(ctx: ctx, ids: ["a", "b", "c"])
        // 초기 대표 = a (가장 빠른 시간). b를 ♥ ON 하면 대표가 b가 되어야 함.
        try FavoriteToggler.toggle(photo: photos[1], context: ctx)
        #expect(photos[1].isFavorite == true)
        #expect(scene.representativePhoto?.assetLocalId == "b")
        #expect(scene.userModifiedAt != nil)
    }

    @Test("♥ OFF — 다른 ♥가 없으면 시간 순 룰로 재선정")
    func turningOffFavoriteFallsBackToEarliest() throws {
        let ctx = try freshContext()
        let (scene, photos) = try seedScene(ctx: ctx, ids: ["a", "b", "c"])
        try FavoriteToggler.toggle(photo: photos[1], context: ctx)
        // 이 시점에 대표 = b. 이제 b를 다시 OFF.
        try FavoriteToggler.toggle(photo: photos[1], context: ctx)
        #expect(photos[1].isFavorite == false)
        #expect(scene.representativePhoto?.assetLocalId == "a")
    }

    @Test("여러 ♥ 중 가장 빠른 capturedAt이 대표")
    func multipleFavoritesPickEarliest() throws {
        let ctx = try freshContext()
        let (scene, photos) = try seedScene(ctx: ctx, ids: ["a", "b", "c"])
        try FavoriteToggler.toggle(photo: photos[2], context: ctx)  // c ♥ → 대표 c
        try FavoriteToggler.toggle(photo: photos[1], context: ctx)  // b ♥ → 대표 b (c보다 빠름)
        #expect(scene.representativePhoto?.assetLocalId == "b")
    }

    @Test("Scene 없는 단독 사진 ♥ 토글은 isFavorite만 갱신")
    func singletonToggleOnlySetsFlag() throws {
        let ctx = try freshContext()
        let trip = Trip(name: "T", startDate: date(2026, 5, 1), endDate: date(2026, 5, 1))
        ctx.insert(trip)
        let day = Day(date: date(2026, 5, 1), trip: trip)
        ctx.insert(day)
        let photo = Photo(day: day, assetLocalId: "x", capturedAt: date(2026, 5, 1))
        ctx.insert(photo)
        try ctx.save()

        try FavoriteToggler.toggle(photo: photo, context: ctx)
        #expect(photo.isFavorite == true)
        #expect(photo.scene == nil)
    }

    @Test("같은 사진을 두 번 토글하면 isFavorite 원위치 + 대표 원위치")
    func doubleToggleIsIdentity() throws {
        let ctx = try freshContext()
        let (scene, photos) = try seedScene(ctx: ctx, ids: ["a", "b"])
        try FavoriteToggler.toggle(photo: photos[1], context: ctx)
        try FavoriteToggler.toggle(photo: photos[1], context: ctx)
        #expect(photos[1].isFavorite == false)
        #expect(scene.representativePhoto?.assetLocalId == "a")
    }
}
