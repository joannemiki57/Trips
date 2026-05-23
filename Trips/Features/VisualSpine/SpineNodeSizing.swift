import Foundation
import CoreGraphics

/// Visual Spine의 Day 마디 크기 = favorite 수에 비례. mvp.md §5.4 "굵게/크게 → 큐레이션 밀도 시각화".
enum SpineNodeSizing {
    /// favorite 0개 — 정리 안 된 Day 표시.
    static let minSize: CGFloat = 6
    /// favorite 1개 — 기본 마디.
    static let baseSize: CGFloat = 10
    /// favorite 많은 Day의 상한.
    static let maxSize: CGFloat = 20

    /// favorite count 증가 시 마디 한 단위(=`step`)씩 커진다, maxSize까지.
    static let step: CGFloat = 2

    static func size(forFavoriteCount count: Int) -> CGFloat {
        guard count > 0 else { return minSize }
        let raw = baseSize + CGFloat(count - 1) * step
        return min(raw, maxSize)
    }
}
