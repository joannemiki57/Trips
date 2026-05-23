import Foundation
import Photos
import Vision
import CoreGraphics
import ImageIO
import UIKit

/// Vision `VNGenerateImageFeaturePrintRequest`로 PHAsset의 featureprint 추출.
/// 호출은 비동기 (백그라운드 Task에서 실제 디코딩 + Vision 실행). 결과는 메인 액터의 캐시에 보존.
@MainActor
final class VisionFeaturePrintExtractor {

    /// @unchecked Sendable wrapper — VNFeaturePrintObservation은 생성 이후 immutable.
    private struct ObservationBox: @unchecked Sendable {
        let value: VNFeaturePrintObservation
    }

    private var cache: [String: VNFeaturePrintObservation] = [:]

    func featurePrint(for assetLocalId: String) async -> VNFeaturePrintObservation? {
        if let hit = cache[assetLocalId] {
            return hit
        }
        // 1) 메인 액터에서 PHImageManager로 이미지 로드 (ThumbnailLoader와 같은 큐 컨텍스트).
        guard let cgImage = await loadCGImage(for: assetLocalId) else { return nil }

        // 2) Vision 처리는 백그라운드 Task에서.
        struct CGImageBox: @unchecked Sendable { let value: CGImage }
        let imageBox = CGImageBox(value: cgImage)
        let boxed: ObservationBox? = await Task.detached(priority: .userInitiated) {
            guard let value = Self.computeFeaturePrint(cgImage: imageBox.value) else { return nil }
            return ObservationBox(value: value)
        }.value

        if let boxed {
            cache[assetLocalId] = boxed.value
            return boxed.value
        }
        return nil
    }

    private func loadCGImage(for assetLocalId: String) async -> CGImage? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalId], options: nil)
        guard let asset = fetch.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        let image: UIImage? = await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
            nonisolated(unsafe) var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 256, height: 256),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if resumed { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                resumed = true
                cont.resume(returning: image)
            }
        }
        return image?.cgImage
    }

    private nonisolated static func computeFeaturePrint(cgImage: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        // 시뮬레이터는 Apple Neural Engine이 없어 espresso(Core ML) 컨텍스트 생성 실패.
        // deprecated이지만 실 디바이스에서도 안전한 CPU 강제 플래그로 폴백.
        request.usesCPUOnly = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        return request.results?.first as? VNFeaturePrintObservation
    }

    /// 두 featureprint 사이의 거리 — 0에 가까울수록 비슷. Vision 내부 계산.
    nonisolated func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float {
        var d: Float = 0
        try? a.computeDistance(&d, to: b)
        return d
    }

}
