import Testing
import Foundation
import CoreGraphics
@testable import Trips

@Suite("VisualSpine · 마디 크기 매핑")
struct SpineNodeSizingTests {

    @Test("favorite 0개 → minimum size (옅은 노드)")
    func zeroFavoritesUsesMinimum() {
        #expect(SpineNodeSizing.size(forFavoriteCount: 0) == SpineNodeSizing.minSize)
    }

    @Test("favorite 1개 → base size")
    func oneFavoriteUsesBase() {
        #expect(SpineNodeSizing.size(forFavoriteCount: 1) == SpineNodeSizing.baseSize)
    }

    @Test("favorite 5개 → base + bonus, 단 maxSize 한도")
    func fiveFavoritesIncreasesProportionally() {
        let size = SpineNodeSizing.size(forFavoriteCount: 5)
        #expect(size > SpineNodeSizing.baseSize)
        #expect(size <= SpineNodeSizing.maxSize)
    }

    @Test("favorite 매우 많아도 maxSize 넘지 않음")
    func clampsToMaxSize() {
        #expect(SpineNodeSizing.size(forFavoriteCount: 100) == SpineNodeSizing.maxSize)
    }

    @Test("favorite count 증가는 단조 비감소")
    func monotonicallyNonDecreasing() {
        var last: CGFloat = 0
        for n in 0...10 {
            let s = SpineNodeSizing.size(forFavoriteCount: n)
            #expect(s >= last)
            last = s
        }
    }
}
