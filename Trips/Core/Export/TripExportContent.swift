import Foundation

/// Export 입력 정규화 — `Trip`의 favorite만 Day별로 추려 페이지 구성.
/// favorite이 한 장도 없는 Day는 페이지 자체를 생략한다.
struct TripExportContent {
    let trip: Trip

    struct DayPage: Identifiable {
        let day: Day
        let favorites: [Photo]
        var id: UUID { day.id }
    }

    var dayPages: [DayPage] {
        trip.days
            .sorted { $0.date < $1.date }
            .compactMap { day in
                let favs = day.photos
                    .filter { $0.isFavorite }
                    .sorted { $0.capturedAt < $1.capturedAt }
                return favs.isEmpty ? nil : DayPage(day: day, favorites: favs)
            }
    }

    /// 표지 1장 + favorite 있는 Day 수.
    var pageCount: Int {
        1 + dayPages.count
    }
}
