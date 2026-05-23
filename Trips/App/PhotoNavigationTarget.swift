import Foundation

/// 사진 카드 탭의 결과를 두 경로로 분기 — 같은 Photo 타입이라 NavigationStack에서
/// 단일 navigationDestination(for: Photo.self)로는 분기 못함. 라우팅 키.
enum PhotoNavigationTarget: Hashable {
    case cluster(Photo)
    case detail(Photo)
}
