import Testing
import Foundation
import SwiftData
import UIKit
import CoreGraphics
@testable import Trips

@Suite("TripPDFRenderer · 표지 1p + Day당 1p 페이지 생성")
@MainActor
struct TripPDFRendererTests {

    /// 단색 PNG를 돌려주는 stub. 실제 PHImageManager 호출 없이 렌더 검증.
    struct SolidColorProvider: PhotoImageDataProvider {
        let color: UIColor

        func data(for photo: Photo) async -> Data? {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
            let image = renderer.image { ctx in
                color.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            }
            return image.pngData()
        }
    }

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
        let trip = Trip(
            name: "Toronto Trip",
            startDate: date(2026, 5, 1),
            endDate: date(2026, 5, days.count)
        )
        ctx.insert(trip)
        for (dayIndex, favs) in days.enumerated() {
            let day = Day(date: date(2026, 5, dayIndex + 1), trip: trip)
            ctx.insert(day)
            for (photoIndex, isFav) in favs.enumerated() {
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

    @Test("출력 PDF가 비어있지 않음")
    func dataIsNonEmpty() async throws {
        let ctx = try freshContext()
        let trip = try seed(ctx: ctx, days: [[true]])
        let data = await TripPDFRenderer.render(
            content: TripExportContent(trip: trip),
            provider: SolidColorProvider(color: .systemBlue)
        )
        #expect(data.isEmpty == false)
    }

    @Test("페이지 수 = 표지(1) + favorite 있는 Day 수")
    func pageCountMatches() async throws {
        let ctx = try freshContext()
        let trip = try seed(ctx: ctx, days: [
            [true],          // Day 1
            [true, true],    // Day 2
            [false],         // Day 3 (스킵)
            [true]           // Day 4
        ])
        let data = await TripPDFRenderer.render(
            content: TripExportContent(trip: trip),
            provider: SolidColorProvider(color: .systemRed)
        )
        let doc = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        #expect(doc.numberOfPages == 4)  // cover + 3 Days with favs
    }

    @Test("favorite 0개여도 표지 1p는 나옴")
    func coverOnlyWhenNoFavorites() async throws {
        let ctx = try freshContext()
        let trip = try seed(ctx: ctx, days: [[false], [false]])
        let data = await TripPDFRenderer.render(
            content: TripExportContent(trip: trip),
            provider: SolidColorProvider(color: .systemGreen)
        )
        let doc = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        #expect(doc.numberOfPages == 1)
    }

    @Test("페이지 크기 = A4 portrait (595 x 842)")
    func pageSizeIsA4() async throws {
        let ctx = try freshContext()
        let trip = try seed(ctx: ctx, days: [[true]])
        let data = await TripPDFRenderer.render(
            content: TripExportContent(trip: trip),
            provider: SolidColorProvider(color: .systemPurple)
        )
        let doc = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        let page = try #require(doc.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        #expect(Int(box.width) == 595)
        #expect(Int(box.height) == 842)
    }
}
