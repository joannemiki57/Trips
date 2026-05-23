import Foundation
import SwiftData
import Vision

/// PhotoKit → B1·B2 → SwiftData 파이프라인을 한 곳에 모은 서비스.
/// UI state는 호출자가 들고, 이 타입은 순수하게 IO + 알고리즘 + 영속화만 담당.
/// **W2 한계** — homeAnchor는 nil (W3에서 자동 추정 도입). 재실행 시 Photo는 멱등 재사용되나
/// Trip 행은 누적된다 (W3에서 정리 로직 추가).
@MainActor
struct TripImportService {

    let context: ModelContext

    struct Result: Equatable {
        let scanned: Int
        let trips: Int
        let photosImported: Int
    }

    func run(extractor: VisionFeaturePrintExtractor = VisionFeaturePrintExtractor()) async throws -> Result {
        var metadata: [PhotoMetadata] = []
        for await meta in PhotoMetadataAdapter.streamAllImages() {
            metadata.append(meta)
        }

        let candidates = TripGrouping.group(photos: metadata, homeAnchor: nil)
        let importer = TripImporter(context: context)

        var tripCount = 0
        var photoCount = 0
        for (index, candidate) in candidates.enumerated() {
            let fallback = String(localized: "triplist.defaultName \(index + 1)")
            let geocoded = await TripLocationNamer.name(forCentroid: candidate.centroid)
            let trip = try importer.importCandidate(
                candidate,
                fallbackName: geocoded ?? fallback
            )

            // B3 — 각 사진의 featureprint를 추출하고, 그 거리를 사용해 Scene 생성.
            var featurePrints: [String: VNFeaturePrintObservation] = [:]
            for meta in candidate.photos {
                if let fp = await extractor.featurePrint(for: meta.assetLocalId) {
                    featurePrints[meta.assetLocalId] = fp
                }
            }
            try importer.generateScenes(
                for: trip,
                candidateMetadata: candidate.photos,
                featurePrintDistance: { idA, idB in
                    guard let a = featurePrints[idA], let b = featurePrints[idB] else {
                        return nil
                    }
                    return extractor.distance(a, b)
                }
            )

            tripCount += 1
            photoCount += trip.days.reduce(0) { $0 + $1.photos.count }
        }
        try context.save()
        try Self.purgeEmptyTrips(context: context)

        return Result(
            scanned: metadata.count,
            trips: tripCount,
            photosImported: photoCount
        )
    }

    /// 모든 Day가 비어 있는 Trip을 삭제. 재스캔 시 Photo들이 새 Trip의 Day로 reassign 되면서
    /// 남은 잔재 행을 정리한다. 빈 Day만 cascade로 같이 사라지고, Photo는 손실 없음.
    /// W3 이전까지 멱등 재스캔의 유일한 정리 메커니즘.
    static func purgeEmptyTrips(context: ModelContext) throws {
        let trips = try context.fetch(FetchDescriptor<Trip>())
        var didChange = false
        for trip in trips where trip.days.allSatisfy({ $0.photos.isEmpty }) {
            context.delete(trip)
            didChange = true
        }
        if didChange {
            try context.save()
        }
    }
}
