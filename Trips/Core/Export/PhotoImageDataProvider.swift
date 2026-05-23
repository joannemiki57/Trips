import Foundation

/// PDF/album용 이미지 데이터 소스 추상화.
/// 실서비스: `PhotoKitImageDataProvider` (PHImageManager). 테스트: 솔리드 컬러 stub.
/// `Photo`(@Model)을 직접 받으므로 MainActor 격리.
@MainActor
protocol PhotoImageDataProvider {
    func data(for photo: Photo) async -> Data?
}
