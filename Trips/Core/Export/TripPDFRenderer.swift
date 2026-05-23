import Foundation
import UIKit
import CoreGraphics

/// Trip favorite → PDF 변환. A4 portrait, 표지 1p + Day당 1p.
/// mvp.md §5.5 ("사진첩 형태 PDF export") + §5.4 (Spine을 골격으로).
@MainActor
enum TripPDFRenderer {
    /// A4 portrait, pt 단위 (72dpi 기준).
    static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 48
    private static let photoGap: CGFloat = 12

    static func render(
        content: TripExportContent,
        provider: PhotoImageDataProvider
    ) async -> Data {
        let dayPages = content.dayPages

        // 이미지 미리 로드 (페이지 그리기는 동기 컨텍스트라서 await 못 함).
        var images: [UUID: UIImage] = [:]
        for page in dayPages {
            for photo in page.favorites {
                if let bytes = await provider.data(for: photo),
                   let img = UIImage(data: bytes) {
                    images[photo.id] = img
                }
            }
        }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: content.trip.name,
            kCGPDFContextCreator as String: "Trips"
        ]
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: format
        )

        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawCover(trip: content.trip, in: ctx.cgContext)
            for page in dayPages {
                ctx.beginPage()
                drawDayPage(page, images: images, in: ctx.cgContext)
            }
        }
    }

    // MARK: - Cover

    private static func drawCover(trip: Trip, in ctx: CGContext) {
        let title = trip.name
        let dateRange = formatRange(start: trip.startDate, end: trip.endDate)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 42, weight: .heavy),
            .foregroundColor: UIColor.black
        ]
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]

        let titleSize = (title as NSString).size(withAttributes: titleAttrs)
        let dateSize = (dateRange as NSString).size(withAttributes: dateAttrs)

        let totalH = titleSize.height + 16 + dateSize.height
        let originY = (pageSize.height - totalH) / 2

        (title as NSString).draw(
            at: CGPoint(x: (pageSize.width - titleSize.width) / 2, y: originY),
            withAttributes: titleAttrs
        )
        (dateRange as NSString).draw(
            at: CGPoint(x: (pageSize.width - dateSize.width) / 2,
                        y: originY + titleSize.height + 16),
            withAttributes: dateAttrs
        )
    }

    // MARK: - Day page

    private static func drawDayPage(
        _ page: TripExportContent.DayPage,
        images: [UUID: UIImage],
        in ctx: CGContext
    ) {
        // 헤더
        let header = formatDayHeader(page.day)
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let headerOrigin = CGPoint(x: margin, y: margin)
        (header as NSString).draw(at: headerOrigin, withAttributes: headerAttrs)

        let headerHeight = (header as NSString)
            .size(withAttributes: headerAttrs).height

        let gridY = headerOrigin.y + headerHeight + 24
        let gridRect = CGRect(
            x: margin,
            y: gridY,
            width: pageSize.width - margin * 2,
            height: pageSize.height - gridY - margin
        )
        drawPhotoGrid(
            photos: page.favorites,
            images: images,
            in: gridRect,
            ctx: ctx
        )
    }

    // MARK: - Grid

    /// 2열 그리드 — 사진 수에 따라 행 자동. 1장이면 단독 큰 칸.
    private static func drawPhotoGrid(
        photos: [Photo],
        images: [UUID: UIImage],
        in rect: CGRect,
        ctx: CGContext
    ) {
        guard !photos.isEmpty else { return }

        let columns = photos.count == 1 ? 1 : 2
        let rows = Int(ceil(Double(photos.count) / Double(columns)))

        let cellWidth = (rect.width - photoGap * CGFloat(columns - 1)) / CGFloat(columns)
        let cellHeight = (rect.height - photoGap * CGFloat(rows - 1)) / CGFloat(rows)

        for (index, photo) in photos.enumerated() {
            let col = index % columns
            let row = index / columns
            let cell = CGRect(
                x: rect.minX + CGFloat(col) * (cellWidth + photoGap),
                y: rect.minY + CGFloat(row) * (cellHeight + photoGap),
                width: cellWidth,
                height: cellHeight
            )
            drawPhoto(images[photo.id], in: cell, ctx: ctx)
        }
    }

    private static func drawPhoto(_ image: UIImage?, in cell: CGRect, ctx: CGContext) {
        guard let image else {
            UIColor.systemGray5.setFill()
            UIBezierPath(roundedRect: cell, cornerRadius: 8).fill()
            return
        }
        // aspect-fit
        let imgRatio = image.size.width / image.size.height
        let cellRatio = cell.width / cell.height
        let fit: CGRect
        if imgRatio > cellRatio {
            let h = cell.width / imgRatio
            fit = CGRect(x: cell.minX, y: cell.midY - h / 2, width: cell.width, height: h)
        } else {
            let w = cell.height * imgRatio
            fit = CGRect(x: cell.midX - w / 2, y: cell.minY, width: w, height: cell.height)
        }
        ctx.saveGState()
        UIBezierPath(roundedRect: fit, cornerRadius: 8).addClip()
        image.draw(in: fit)
        ctx.restoreGState()
    }

    // MARK: - Format helpers

    private static func formatRange(start: Date, end: Date) -> String {
        let f = Date.FormatStyle()
            .month(.abbreviated)
            .day()
            .year()
        return "\(start.formatted(f)) – \(end.formatted(f))"
    }

    private static func formatDayHeader(_ day: Day) -> String {
        day.date.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .month(.abbreviated)
                .day()
                .year()
        )
    }
}
