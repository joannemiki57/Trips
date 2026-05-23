import Testing
import Foundation
import SwiftData
@testable import Trips

@Suite("TripExportContent · favorite만 Day별 페이지 구성")
@MainActor
struct TripExportContentTests {

    private func freshContext() throws -> ModelContext {
        let container = try TripsModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: comps)!
    }

    private func seed(ctx: ModelContext, days: [[Bool]]) throws -> Trip {
        // days[i] = i번째 Day의 사진들. 각 Bool = isFavorite.
        let trip = Trip(
            name: "T",
            startDate: date(2026, 5, 1),
            endDate: date(2026, 5, days.count)
        )
        ctx.insert(trip)
        for (dayIndex, favorites) in days.enumerated() {
            let day = Day(date: date(2026, 5, dayIndex + 1), trip: trip)
            ctx.insert(day)
            for (photoIndex, isFav) in favorites.enumerated() {
                let p = Photo(
                    day: day,
                    assetLocalId: "d\(dayIndex)-p\(photoIndex)",
                    capturedAt: date(2026, 5, dayIndex + 1, photoIndex)
                )
                p.isFavorite = isFav
                ctx.insert(p)
            }
        }
        try ctx.save()
        return trip
    }

    @Test("favorite 없는 Day는 페이지에서 제외")
    func skipsDaysWithoutFavorites() throws {
        let ctx = try freshContext()
        let trip = try seed(ctx: ctx, days: [
            [true, false],   // Day 1 — 1 fav
            [false, false],  // Day 2 — 0 favs (스킵)
            [true, true]     // Day 3 — 2 favs
        ])
        let pages = TripExportContent(trip: trip).dayPages
        #expect(pages.count == 2)
        #expect(pages[0].favorites.count == 1)
        #expect(pages[1].favorites.count == 2)
    }

    @Test("pageCount = 표지(1) + favorite 있는 Day 수")
    func pageCountIncludesCover() throws {
        let ctx = try freshContext()
        let trip = try seed(ctx: ctx, days: [[true], [true], [false]])
        #expect(TripExportContent(trip: trip).pageCount == 3)  // cover + 2 Day pages
    }

    @Test("Day 순서는 date 오름차순")
    func daysSortedAscending() throws {
        let ctx = try freshContext()
        let trip = try seed(ctx: ctx, days: [[true], [true], [true]])
        let pages = TripExportContent(trip: trip).dayPages
        #expect(pages[0].day.date < pages[1].day.date)
        #expect(pages[1].day.date < pages[2].day.date)
    }

    @Test("Day 안 favorite 정렬은 capturedAt 오름차순")
    func favoritesSortedByCapturedAt() throws {
        let ctx = try freshContext()
        // 한 Day에 fav 3장, 일부러 시간 안 맞춰 넣음
        let trip = Trip(name: "T", startDate: date(2026, 5, 1), endDate: date(2026, 5, 1))
        ctx.insert(trip)
        let day = Day(date: date(2026, 5, 1), trip: trip)
        ctx.insert(day)
        let p2 = Photo(day: day, assetLocalId: "p2", capturedAt: date(2026, 5, 1, 14))
        let p1 = Photo(day: day, assetLocalId: "p1", capturedAt: date(2026, 5, 1, 10))
        let p3 = Photo(day: day, assetLocalId: "p3", capturedAt: date(2026, 5, 1, 18))
        [p1, p2, p3].forEach { $0.isFavorite = true; ctx.insert($0) }
        try ctx.save()

        let pages = TripExportContent(trip: trip).dayPages
        #expect(pages[0].favorites.map(\.assetLocalId) == ["p1", "p2", "p3"])
    }

    @Test("favorite 0개면 dayPages 빈 배열 + pageCount=1 (표지만)")
    func zeroFavoritesYieldsCoverOnly() throws {
        let ctx = try freshContext()
        let trip = try seed(ctx: ctx, days: [[false], [false]])
        let content = TripExportContent(trip: trip)
        #expect(content.dayPages.isEmpty)
        #expect(content.pageCount == 1)
    }
}
