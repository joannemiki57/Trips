import Foundation

/// B2 — Day 분할. selection.md §E·§G LOCKED:
/// - 촬영 위치 로컬 타임존 캘린더 날짜
/// - **03:00 이전 사진은 전날 Day로 귀속**
/// - 시스템 타임존 그대로 쓰지 말 것. EXIF tz → 좌표 유도 tz → fallback tz 순.
enum DaySplit {

    /// 03:00 룰 — 새벽 사진을 전날로 귀속시키기 위한 시간 시프트.
    static let preDawnShift: TimeInterval = 3 * 60 * 60

    struct Day: Equatable, Sendable {
        /// 사진들이 속한 논리적 캘린더 날짜의 00:00 (해당 타임존 기준).
        let logicalDate: Date
        let timeZone: TimeZone
        let photos: [PhotoMetadata]
    }

    /// Resolver for a photo's timezone. EXIF tz → 좌표 유도 → fallback.
    /// 좌표 유도(CLGeocoder)는 네트워크·async가 필요해 v1에서는 호출자가 미리 PhotoMetadata.timeZone에
    /// 채워주는 것을 전제로 한다. v1.1에서 비동기 리졸버 추가 가능.
    struct Resolver: Sendable {
        let fallback: TimeZone

        init(fallback: TimeZone = .current) {
            self.fallback = fallback
        }

        func timeZone(for photo: PhotoMetadata) -> TimeZone {
            photo.timeZone ?? fallback
        }
    }

    /// 사진을 Day 단위로 묶음. 입력 정렬 여부와 무관.
    /// 출력은 logicalDate 오름차순. 한 Day 내 photos는 capturedAt 오름차순.
    static func split(
        photos: [PhotoMetadata],
        resolver: Resolver = Resolver()
    ) -> [Day] {
        guard !photos.isEmpty else { return [] }

        // 그룹 키 = (logicalDate, timezone identifier)
        struct Key: Hashable {
            let logicalDate: Date
            let tzIdentifier: String
        }

        var buckets: [Key: (timeZone: TimeZone, photos: [PhotoMetadata])] = [:]

        for photo in photos {
            let tz = resolver.timeZone(for: photo)
            let logical = logicalDate(for: photo.capturedAt, in: tz)
            let key = Key(logicalDate: logical, tzIdentifier: tz.identifier)
            buckets[key, default: (tz, [])].photos.append(photo)
        }

        return buckets
            .map { key, value in
                Day(
                    logicalDate: key.logicalDate,
                    timeZone: value.timeZone,
                    photos: value.photos.sorted { $0.capturedAt < $1.capturedAt }
                )
            }
            .sorted { $0.logicalDate < $1.logicalDate }
    }

    /// 단일 사진의 논리 날짜를 계산. 03:00 룰 적용.
    static func logicalDate(for capturedAt: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let shifted = capturedAt.addingTimeInterval(-preDawnShift)
        return calendar.startOfDay(for: shifted)
    }
}
