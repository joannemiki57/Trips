import Testing
import Foundation
@testable import Trips

/// B2 LOCKED — 03:00 룰 + EXIF tz → fallback. algorithms.md 경계 케이스: 23:50, 01:20, 03:00 정확.
@Suite("DaySplit (B2)")
struct DaySplitTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let seoul = TimeZone(identifier: "Asia/Seoul")!
    private let nyt = TimeZone(identifier: "America/New_York")!

    /// 특정 타임존의 wall-clock 시각으로 Date 생성.
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, tz: TimeZone) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        comps.hour = h; comps.minute = min
        comps.timeZone = tz
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: comps)!
    }

    private func photo(at date: Date, tz: TimeZone? = nil) -> PhotoMetadata {
        PhotoMetadata(
            assetLocalId: "p-\(date.timeIntervalSince1970)",
            capturedAt: date,
            coordinate: nil,
            timeZone: tz
        )
    }

    // MARK: - 03:00 boundary

    @Test("02:59 → 전날 Day로 귀속")
    func twoFiftyNineMapsToPreviousDay() {
        let d = date(2026, 5, 20, 2, 59, tz: tokyo)
        let result = DaySplit.split(photos: [photo(at: d, tz: tokyo)])
        #expect(result.count == 1)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tokyo
        let expectedLogical = cal.startOfDay(for: date(2026, 5, 19, 12, 0, tz: tokyo))
        #expect(result[0].logicalDate == expectedLogical)
    }

    @Test("03:00 정각 → 오늘 Day")
    func threeAMExactMapsToCurrentDay() {
        let d = date(2026, 5, 20, 3, 0, tz: tokyo)
        let result = DaySplit.split(photos: [photo(at: d, tz: tokyo)])
        #expect(result.count == 1)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tokyo
        let expectedLogical = cal.startOfDay(for: date(2026, 5, 20, 12, 0, tz: tokyo))
        #expect(result[0].logicalDate == expectedLogical)
    }

    @Test("03:01 → 오늘 Day")
    func threeAMOnePastMapsToCurrentDay() {
        let d = date(2026, 5, 20, 3, 1, tz: tokyo)
        let result = DaySplit.split(photos: [photo(at: d, tz: tokyo)])
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tokyo
        let expectedLogical = cal.startOfDay(for: date(2026, 5, 20, 12, 0, tz: tokyo))
        #expect(result[0].logicalDate == expectedLogical)
    }

    @Test("23:50 → 오늘 Day (전날 아님)")
    func almostMidnightMapsToCurrentDay() {
        let d = date(2026, 5, 20, 23, 50, tz: tokyo)
        let result = DaySplit.split(photos: [photo(at: d, tz: tokyo)])
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tokyo
        let expectedLogical = cal.startOfDay(for: date(2026, 5, 20, 12, 0, tz: tokyo))
        #expect(result[0].logicalDate == expectedLogical)
    }

    @Test("01:20 → 전날 Day로 귀속")
    func oneTwentyAMMapsToPreviousDay() {
        let d = date(2026, 5, 20, 1, 20, tz: tokyo)
        let result = DaySplit.split(photos: [photo(at: d, tz: tokyo)])
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tokyo
        let expectedLogical = cal.startOfDay(for: date(2026, 5, 19, 12, 0, tz: tokyo))
        #expect(result[0].logicalDate == expectedLogical)
    }

    // MARK: - 23:50~01:20 같은 연속 구간

    @Test("23:50 → 02:30 연속 사진 = 한 Day로 묶임")
    func contiguousNightSpanGroupsTogether() {
        let lateNight = date(2026, 5, 20, 23, 50, tz: tokyo)
        let pastMidnight = date(2026, 5, 21, 0, 30, tz: tokyo)
        let preDawn = date(2026, 5, 21, 2, 30, tz: tokyo)
        let result = DaySplit.split(photos: [
            photo(at: lateNight, tz: tokyo),
            photo(at: pastMidnight, tz: tokyo),
            photo(at: preDawn, tz: tokyo)
        ])
        // 모두 5/20 Day로 귀속되어야 함 (00:30, 02:30은 전날로 시프트)
        #expect(result.count == 1)
        #expect(result[0].photos.count == 3)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tokyo
        #expect(result[0].logicalDate == cal.startOfDay(for: date(2026, 5, 20, 12, 0, tz: tokyo)))
    }

    // MARK: - Empty / single

    @Test("빈 입력 → 빈 결과")
    func emptyInput() {
        #expect(DaySplit.split(photos: []).isEmpty)
    }

    @Test("사진 1장 → 1 Day")
    func singlePhoto() {
        let d = date(2026, 5, 20, 14, 0, tz: tokyo)
        let result = DaySplit.split(photos: [photo(at: d, tz: tokyo)])
        #expect(result.count == 1)
        #expect(result[0].photos.count == 1)
    }

    // MARK: - Cross-timezone

    @Test("같은 wall-clock 날짜라도 타임존이 다르면 별도 Day")
    func differentTimeZonesProduceSeparateDays() {
        // 도쿄 14:00 2026-05-20 와 NYT 14:00 2026-05-20 — UTC 14h 차이
        let tokyoNoon = date(2026, 5, 20, 14, 0, tz: tokyo)
        let nytNoon = date(2026, 5, 20, 14, 0, tz: nyt)
        let result = DaySplit.split(photos: [
            photo(at: tokyoNoon, tz: tokyo),
            photo(at: nytNoon, tz: nyt)
        ])
        #expect(result.count == 2)
    }

    @Test("같은 capturedAt이라도 timezone resolver가 다르게 주면 다른 Day")
    func resolverDeterminesDayBoundary() {
        let utcMidnight = Date(timeIntervalSince1970: 1_716_163_200) // 2024-05-20 00:00 UTC
        // Tokyo (UTC+9): 09:00 2024-05-20 → 5/20 Day
        // NYT (UTC-4 DST): 20:00 2024-05-19 → 5/19 Day
        let tokyoPhoto = photo(at: utcMidnight, tz: tokyo)
        let nytPhoto = photo(at: utcMidnight, tz: nyt)
        let result = DaySplit.split(photos: [tokyoPhoto, nytPhoto])
        #expect(result.count == 2)
    }

    // MARK: - Resolver fallback

    @Test("photo.timeZone nil이면 resolver의 fallback 사용")
    func fallbackTimeZoneUsedWhenMissing() {
        let d = date(2026, 5, 20, 14, 0, tz: seoul)
        let withoutTZ = photo(at: d, tz: nil)
        let result = DaySplit.split(
            photos: [withoutTZ],
            resolver: DaySplit.Resolver(fallback: seoul)
        )
        #expect(result.count == 1)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = seoul
        #expect(result[0].logicalDate == cal.startOfDay(for: date(2026, 5, 20, 12, 0, tz: seoul)))
        #expect(result[0].timeZone.identifier == seoul.identifier)
    }

    // MARK: - Ordering / sorting

    @Test("결과 Day들은 logicalDate 오름차순")
    func daysAreSortedAscending() {
        let d1 = date(2026, 5, 18, 14, 0, tz: tokyo)
        let d2 = date(2026, 5, 20, 14, 0, tz: tokyo)
        let d3 = date(2026, 5, 19, 14, 0, tz: tokyo)
        let result = DaySplit.split(photos: [
            photo(at: d2, tz: tokyo),
            photo(at: d1, tz: tokyo),
            photo(at: d3, tz: tokyo)
        ])
        #expect(result.count == 3)
        #expect(result[0].logicalDate < result[1].logicalDate)
        #expect(result[1].logicalDate < result[2].logicalDate)
    }

    @Test("Day 내 photos는 capturedAt 오름차순")
    func photosWithinDayAreSorted() {
        let early = date(2026, 5, 20, 10, 0, tz: tokyo)
        let mid = date(2026, 5, 20, 14, 0, tz: tokyo)
        let late = date(2026, 5, 20, 22, 0, tz: tokyo)
        let result = DaySplit.split(photos: [
            photo(at: late, tz: tokyo),
            photo(at: early, tz: tokyo),
            photo(at: mid, tz: tokyo)
        ])
        #expect(result.count == 1)
        let times = result[0].photos.map(\.capturedAt)
        #expect(times == [early, mid, late])
    }

    // MARK: - EXIF tz end-to-end (A4)

    @Test("같은 UTC 인스턴트 + 다른 EXIF tz → 다른 logical Day")
    func sameInstantDifferentTimeZonesProduceDifferentDays() {
        // 2026-05-20 22:00 UTC
        // → KST(+09): 2026-05-21 07:00 → logical 2026-05-21
        // → PST(-08): 2026-05-20 14:00 → logical 2026-05-20
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 20
        comps.hour = 22; comps.minute = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)!
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let utcInstant = utcCal.date(from: comps)!

        let kst = TimeZone(secondsFromGMT: 9 * 3600)!
        let pst = TimeZone(secondsFromGMT: -8 * 3600)!

        let result = DaySplit.split(photos: [
            photo(at: utcInstant, tz: kst),
            photo(at: utcInstant, tz: pst)
        ])
        #expect(result.count == 2)

        var kstCal = Calendar(identifier: .gregorian); kstCal.timeZone = kst
        var pstCal = Calendar(identifier: .gregorian); pstCal.timeZone = pst
        let expectedKstDay = kstCal.startOfDay(for: date(2026, 5, 21, 12, 0, tz: kst))
        let expectedPstDay = pstCal.startOfDay(for: date(2026, 5, 20, 12, 0, tz: pst))
        let logicalDates = Set(result.map(\.logicalDate))
        #expect(logicalDates.contains(expectedKstDay))
        #expect(logicalDates.contains(expectedPstDay))
    }

    @Test("photo.timeZone nil → resolver fallback 사용")
    func nilPhotoTimeZoneFallsBackToResolverDefault() {
        let utcCal: Calendar = {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(secondsFromGMT: 0)!
            return c
        }()
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 20
        comps.hour = 22; comps.minute = 0
        comps.timeZone = TimeZone(secondsFromGMT: 0)!
        let utcInstant = utcCal.date(from: comps)!

        let resolver = DaySplit.Resolver(fallback: TimeZone(secondsFromGMT: 9 * 3600)!)
        let result = DaySplit.split(
            photos: [photo(at: utcInstant, tz: nil)],
            resolver: resolver
        )
        // 22:00 UTC → KST 07:00 → logical 2026-05-21
        #expect(result.count == 1)
        var kstCal = Calendar(identifier: .gregorian)
        kstCal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let expected = kstCal.startOfDay(
            for: date(2026, 5, 21, 12, 0, tz: TimeZone(secondsFromGMT: 9 * 3600)!)
        )
        #expect(result[0].logicalDate == expected)
    }
}
