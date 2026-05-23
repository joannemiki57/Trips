import Testing
import Foundation
@testable import Trips

@Suite("ExifTimeZone · OffsetTime string parsing")
struct ExifTimeZoneTests {

    @Test("+09:00 (KST) → 32400초")
    func plusNine() {
        #expect(ExifTimeZone.parse(offsetString: "+09:00")?.secondsFromGMT() == 9 * 3600)
    }

    @Test("+05:30 (IST 반시간) → 19800초")
    func plusFiveThirty() {
        #expect(ExifTimeZone.parse(offsetString: "+05:30")?.secondsFromGMT() == 5 * 3600 + 30 * 60)
    }

    @Test("-08:00 (PST) → -28800초")
    func minusEight() {
        #expect(ExifTimeZone.parse(offsetString: "-08:00")?.secondsFromGMT() == -8 * 3600)
    }

    @Test("-03:30 (NST 반시간 음수)")
    func minusThreeThirty() {
        #expect(ExifTimeZone.parse(offsetString: "-03:30")?.secondsFromGMT() == -(3 * 3600 + 30 * 60))
    }

    @Test("+00:00 → UTC")
    func zeroOffset() {
        #expect(ExifTimeZone.parse(offsetString: "+00:00")?.secondsFromGMT() == 0)
    }

    @Test("Z 표기 → UTC")
    func zuluUpper() {
        #expect(ExifTimeZone.parse(offsetString: "Z")?.secondsFromGMT() == 0)
    }

    @Test("z 소문자 → UTC")
    func zuluLower() {
        #expect(ExifTimeZone.parse(offsetString: "z")?.secondsFromGMT() == 0)
    }

    @Test("nil 입력 → nil")
    func nilInput() {
        #expect(ExifTimeZone.parse(offsetString: nil) == nil)
    }

    @Test("빈 문자열 → nil")
    func emptyString() {
        #expect(ExifTimeZone.parse(offsetString: "") == nil)
    }

    @Test("부호 없음 → nil")
    func missingSign() {
        #expect(ExifTimeZone.parse(offsetString: "09:00") == nil)
    }

    @Test("콜론 없음 → nil")
    func missingColon() {
        #expect(ExifTimeZone.parse(offsetString: "+0900") == nil)
    }

    @Test("자릿수 부족 (+9:00) → nil")
    func tooShortHours() {
        #expect(ExifTimeZone.parse(offsetString: "+9:00") == nil)
    }

    @Test("자릿수 부족 (+09:0) → nil")
    func tooShortMinutes() {
        #expect(ExifTimeZone.parse(offsetString: "+09:0") == nil)
    }

    @Test("시간 범위 초과 (+25:00) → nil")
    func hoursOutOfRange() {
        #expect(ExifTimeZone.parse(offsetString: "+25:00") == nil)
    }

    @Test("분 범위 초과 (+09:60) → nil")
    func minutesOutOfRange() {
        #expect(ExifTimeZone.parse(offsetString: "+09:60") == nil)
    }

    @Test("쓰레기 입력 → nil")
    func garbage() {
        #expect(ExifTimeZone.parse(offsetString: "hello") == nil)
    }
}
