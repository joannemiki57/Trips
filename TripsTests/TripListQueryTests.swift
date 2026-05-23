import Testing
import Foundation
import SwiftData
@testable import Trips

/// B-slice W2 — TripList 뷰가 사용할 fetch 시맨틱을 in-memory ModelContainer로 검증.
/// `@Query`는 View 안에서만 작동하므로 같은 SortDescriptor를 직접 돌려본다.
@Suite("TripList · SwiftData fetch")
@MainActor
struct TripListQueryTests {

    private func freshContext() throws -> ModelContext {
        let container = try TripsModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: comps)!
    }

    @Test("startDate 내림차순 정렬 — 최신 여행이 맨 위")
    func tripsAreSortedByStartDateDescending() throws {
        let ctx = try freshContext()
        let oldTrip = Trip(name: "Old", startDate: date(2026, 1, 1), endDate: date(2026, 1, 5))
        let midTrip = Trip(name: "Mid", startDate: date(2026, 3, 1), endDate: date(2026, 3, 5))
        let newTrip = Trip(name: "New", startDate: date(2026, 5, 1), endDate: date(2026, 5, 5))
        ctx.insert(oldTrip); ctx.insert(midTrip); ctx.insert(newTrip)
        try ctx.save()

        let descriptor = FetchDescriptor<Trip>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let fetched = try ctx.fetch(descriptor)
        #expect(fetched.map(\.name) == ["New", "Mid", "Old"])
    }

    @Test("Trip이 없으면 빈 배열")
    func emptyStoreReturnsEmptyArray() throws {
        let ctx = try freshContext()
        let descriptor = FetchDescriptor<Trip>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        #expect(try ctx.fetch(descriptor).isEmpty)
    }

    @Test("Trip의 days 관계 — 같은 ctx 안에서 Day 추가 후 fetch 시 보임")
    func tripDaysRelationLoads() throws {
        let ctx = try freshContext()
        let trip = Trip(name: "T", startDate: date(2026, 5, 1), endDate: date(2026, 5, 3))
        ctx.insert(trip)
        let d1 = Day(date: date(2026, 5, 1), trip: trip)
        let d2 = Day(date: date(2026, 5, 2), trip: trip)
        ctx.insert(d1); ctx.insert(d2)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Trip>()).first
        #expect(fetched?.days.count == 2)
    }

    @Test("coverPhoto가 nil이면 첫 Day 첫 Photo가 폴백 — 같은 ctx 안에서")
    func coverPhotoFallbackToFirstDayFirstPhoto() throws {
        let ctx = try freshContext()
        let trip = Trip(name: "T", startDate: date(2026, 5, 1), endDate: date(2026, 5, 2))
        ctx.insert(trip)
        let day = Day(date: date(2026, 5, 1), trip: trip)
        ctx.insert(day)
        let p1 = Photo(day: day, assetLocalId: "asset-1", capturedAt: date(2026, 5, 1))
        let p2 = Photo(day: day, assetLocalId: "asset-2", capturedAt: date(2026, 5, 1))
        ctx.insert(p1); ctx.insert(p2)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Trip>()).first!
        #expect(fetched.coverPhoto == nil)  // 명시적 nil 그대로
        let firstPhoto = fetched.days.first?.photos.first
        #expect(firstPhoto != nil)
    }

    // MARK: - purgeEmptyTrips (멱등 재스캔 정리)

    @Test("빈 Trip만 삭제, photos 보존된 Trip은 유지")
    func purgeRemovesEmptyTripsOnly() throws {
        let ctx = try freshContext()

        // 빈 Trip 2개 (Day는 있지만 photos.isEmpty)
        let emptyA = Trip(name: "Empty A", startDate: date(2026, 5, 1), endDate: date(2026, 5, 2))
        ctx.insert(emptyA)
        ctx.insert(Day(date: date(2026, 5, 1), trip: emptyA))
        let emptyB = Trip(name: "Empty B", startDate: date(2026, 5, 3), endDate: date(2026, 5, 4))
        ctx.insert(emptyB)

        // 살아있는 Trip 1개
        let alive = Trip(name: "Alive", startDate: date(2026, 5, 10), endDate: date(2026, 5, 11))
        ctx.insert(alive)
        let aliveDay = Day(date: date(2026, 5, 10), trip: alive)
        ctx.insert(aliveDay)
        let photo = Photo(day: aliveDay, assetLocalId: "asset-alive", capturedAt: date(2026, 5, 10))
        ctx.insert(photo)
        try ctx.save()

        try TripImportService.purgeEmptyTrips(context: ctx)

        let remaining = try ctx.fetch(FetchDescriptor<Trip>()).map(\.name).sorted()
        #expect(remaining == ["Alive"])

        // 살아있는 trip의 photo도 그대로
        let photos = try ctx.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 1)
        #expect(photos.first?.assetLocalId == "asset-alive")
    }

    @Test("정리할 게 없으면 save 안 부르고 그냥 통과")
    func purgeNoopOnCleanStore() throws {
        let ctx = try freshContext()
        let trip = Trip(name: "X", startDate: date(2026, 5, 1), endDate: date(2026, 5, 2))
        ctx.insert(trip)
        let day = Day(date: date(2026, 5, 1), trip: trip)
        ctx.insert(day)
        ctx.insert(Photo(day: day, assetLocalId: "p", capturedAt: date(2026, 5, 1)))
        try ctx.save()

        try TripImportService.purgeEmptyTrips(context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Trip>()).count == 1)
    }

    // MARK: - TripImporter 재스캔 매칭 (사용자 메타 보존)

    private func metas(_ ids: [String]) -> [PhotoMetadata] {
        ids.enumerated().map { (i, id) in
            PhotoMetadata(
                assetLocalId: id,
                capturedAt: date(2026, 5, 1).addingTimeInterval(TimeInterval(i) * 60),
                coordinate: nil
            )
        }
    }

    @Test("재임포트 시 50%+ 사진 겹치면 기존 Trip 재사용 — 이름 보존")
    func reimportMatchesExistingTripAndPreservesName() throws {
        let ctx = try freshContext()
        let importer = TripImporter(context: ctx)

        // 1차 임포트
        let cand1 = TripCandidate(photos: metas(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]))
        let trip = try importer.importCandidate(cand1, fallbackName: "Toronto")
        try ctx.save()

        // 사용자가 직접 이름 변경
        trip.name = "내가 지은 이름"
        try ctx.save()

        // 2차 임포트 — 같은 사진들 (몇 개 새 사진 추가)
        let cand2 = TripCandidate(photos: metas(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"]))
        let trip2 = try importer.importCandidate(cand2, fallbackName: "Toronto v2")
        try ctx.save()

        #expect(trip2.persistentModelID == trip.persistentModelID)
        #expect(trip2.name == "내가 지은 이름")
        #expect(try ctx.fetch(FetchDescriptor<Trip>()).count == 1)
    }

    @Test("재임포트 시 겹침이 50% 미만이면 새 Trip 생성")
    func reimportNoMatchCreatesNewTrip() throws {
        let ctx = try freshContext()
        let importer = TripImporter(context: ctx)

        let cand1 = TripCandidate(photos: metas(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]))
        let trip = try importer.importCandidate(cand1, fallbackName: "First")
        try ctx.save()
        trip.name = "Edited"
        try ctx.save()

        // 완전히 다른 사진 세트
        let cand2 = TripCandidate(photos: metas(["x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9", "x10"]))
        let trip2 = try importer.importCandidate(cand2, fallbackName: "Second")
        try ctx.save()

        #expect(trip2.persistentModelID != trip.persistentModelID)
        #expect(trip.name == "Edited")
        #expect(trip2.name == "Second")
        #expect(try ctx.fetch(FetchDescriptor<Trip>()).count == 2)
    }

    @Test("재임포트 시 사용자 수정 Scene과 그 멤버 사진은 B3 재계산 대상에서 제외 (7차 라운드)")
    func reimportPreservesUserModifiedScenes() throws {
        let ctx = try freshContext()
        let importer = TripImporter(context: ctx)

        let cand = TripCandidate(photos: metas(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]))
        let trip = try importer.importCandidate(cand, fallbackName: "T")
        try ctx.save()

        // a와 b를 한 Scene으로 묶고 사용자 수정 표시.
        let photoA = try ctx.fetch(FetchDescriptor<Photo>()).first { $0.assetLocalId == "a" }!
        let photoB = try ctx.fetch(FetchDescriptor<Photo>()).first { $0.assetLocalId == "b" }!
        let day = photoA.day!
        let userScene = Scene(day: day)
        ctx.insert(userScene)
        photoA.scene = userScene
        photoB.scene = userScene
        userScene.representativePhoto = photoA
        userScene.userModifiedAt = .now
        try ctx.save()

        // Rescan — 같은 후보 다시.
        _ = try importer.importCandidate(cand, fallbackName: "T")
        try ctx.save()

        // 모든 사진을 한 Scene으로 묶어버리는 closure (B3가 그렇게 동작한다고 가정).
        // 그래도 a/b는 보존된 Scene에 있으니 새 Scene에 들어가면 안 됨.
        try importer.generateScenes(
            for: trip,
            candidateMetadata: cand.photos,
            featurePrintDistance: { _, _ in 0.0 }
        )
        try ctx.save()

        // a, b의 scene은 여전히 userScene 그대로.
        #expect(photoA.scene?.userModifiedAt != nil)
        #expect(photoB.scene?.userModifiedAt != nil)
        #expect(photoA.scene?.persistentModelID == photoB.scene?.persistentModelID)

        // 나머지 8장 (c-j)은 새 Scene(자동 생성, userModifiedAt == nil)에 묶여야 함.
        let photoC = try ctx.fetch(FetchDescriptor<Photo>()).first { $0.assetLocalId == "c" }!
        #expect(photoC.scene?.userModifiedAt == nil)
        // userScene과 다른 Scene이어야.
        #expect(photoC.scene?.persistentModelID != photoA.scene?.persistentModelID)
    }

    @Test("재임포트 시 사용자 지정 coverPhoto 보존")
    func reimportPreservesUserCoverPhoto() throws {
        let ctx = try freshContext()
        let importer = TripImporter(context: ctx)

        let cand = TripCandidate(photos: metas(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]))
        let trip = try importer.importCandidate(cand, fallbackName: "T")
        try ctx.save()

        // 사용자가 5번째 사진을 cover로 지정 (다른 행)
        let photos = try ctx.fetch(FetchDescriptor<Photo>())
        let userPick = photos.first { $0.assetLocalId == "e" }
        trip.coverPhoto = userPick
        try ctx.save()

        // 재임포트
        _ = try importer.importCandidate(cand, fallbackName: "T-new")
        try ctx.save()

        #expect(trip.coverPhoto?.assetLocalId == "e")
    }
}
