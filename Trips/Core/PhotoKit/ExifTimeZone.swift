import Foundation

/// EXIF `OffsetTimeOriginal` 필드(예: "+09:00", "Z")를 `TimeZone`으로 파싱.
/// B2 LOCKED — DaySplit이 정확한 로컬 캘린더 날짜를 산출하려면 촬영지 tz가 필요.
/// 본 파서는 순수 함수: 외부 SDK·디스크 I/O 없음. EXIF 읽기는 별도 레이어에서.
enum ExifTimeZone {

    /// EXIF 6.0 OffsetTime 표현: `±HH:MM` 또는 `Z`.
    /// 형식이 어긋나거나 범위를 벗어나면 nil — 호출자는 `nil`이면 안전 폴백 사용.
    static func parse(offsetString: String?) -> TimeZone? {
        guard let raw = offsetString else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed == "Z" || trimmed == "z" {
            return TimeZone(secondsFromGMT: 0)
        }

        // 엄격한 ±HH:MM (6자) 만 허용
        guard trimmed.count == 6 else { return nil }
        let sign: Int
        switch trimmed.first {
        case "+": sign = 1
        case "-": sign = -1
        default: return nil
        }

        let body = trimmed.dropFirst()  // "HH:MM"
        let parts = body.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0].count == 2,
              parts[1].count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              (0...23).contains(hours),
              (0...59).contains(minutes) else {
            return nil
        }

        return TimeZone(secondsFromGMT: sign * (hours * 3600 + minutes * 60))
    }
}
