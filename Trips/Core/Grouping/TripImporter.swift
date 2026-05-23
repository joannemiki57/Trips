import Foundation
import SwiftData

/// B1·B2 결과를 SwiftData @Model로 영속화하는 파이프라인.
/// 입력: `TripCandidate` (B1 결과)
/// 출력: `Trip` + 하위 `Day` + `Photo` 인스턴스를 ModelContext에 삽입
///
/// **멱등성**: `Photo.assetLocalId`를 키로 중복 임포트 방지. 이미 있으면 기존 Photo 재사용 + 관계 업데이트만.
/// **Scene 미생성**: B3 유사도 알고리즘 미연결 단계 → 모든 Photo는 일단 Day 직속.
/// `UserSettings.showSinglePhotoAsScene`이 true가 되면 별도 단계에서 1장 Scene 생성.
@MainActor
struct TripImporter {

    let context: ModelContext

    /// 한 trip 후보를 영속화. 사용자 수정(머지/스플릿) 후 호출돼도 OK — 멱등.
    ///
    /// **재스캔 매칭**: 기존 Trip 중 candidate의 사진 ≥50%를 공유하는 것을 찾으면 그 Trip을 재사용한다.
    /// 사용자가 직접 수정한 이름/coverPhoto는 그대로 유지되고, startDate/endDate/Days만 새 입력 기준으로 재구성.
    /// 매칭이 없으면 `fallbackName`으로 새 Trip 생성.
    func importCandidate(
        _ candidate: TripCandidate,
        fallbackName: String,
        resolver: DaySplit.Resolver = DaySplit.Resolver()
    ) throws -> Trip {
        let trip = try resolveOrCreateTrip(for: candidate, fallbackName: fallbackName)
        trip.startDate = candidate.startDate
        trip.endDate = candidate.endDate

        // 사용자 수정 Scene은 Day와의 연결을 일시적으로 끊어 Day cascade 삭제에서 살린다 (7차 라운드).
        let preservedScenes = trip.days.flatMap { day in
            day.scenes.filter { $0.userModifiedAt != nil }
        }
        for scene in preservedScenes {
            scene.day = nil
        }

        // 기존 Day 행은 재구성: Photo는 detach해 보존(추후 resolveOrInsert가 재할당)하고 Day만 cascade로 정리.
        // 자동 Scene은 Day cascade로 같이 삭제 — 위에서 분리한 사용자 수정 Scene만 살아남는다.
        for day in trip.days {
            for photo in day.photos {
                photo.day = nil
            }
        }
        for day in Array(trip.days) {
            context.delete(day)
        }

        let days = DaySplit.split(photos: candidate.photos, resolver: resolver)
        for daySlice in days {
            let day = Day(date: daySlice.logicalDate, trip: trip)
            context.insert(day)
            for meta in daySlice.photos {
                let photo = try resolveOrInsert(meta: meta, day: day)
                photo.day = day
            }
        }

        // 보존된 Scene을 재부착 — 대표(또는 첫) 사진이 새로 배정된 Day에 붙임. 멤버 사진이 모두 사라졌으면 Scene 자체 폐기.
        for scene in preservedScenes {
            let anchor = scene.representativePhoto ?? scene.photos.first
            if let day = anchor?.day {
                scene.day = day
            } else {
                context.delete(scene)
            }
        }

        // coverPhoto 폴백: 첫 Day의 첫 Photo. 사용자가 직접 지정한 값은 유지.
        if trip.coverPhoto == nil {
            trip.coverPhoto = trip.days.first?.photos.first
        }

        return trip
    }

    /// candidate와 사진 집합이 50% 이상 겹치는 기존 Trip을 찾아 재사용. 없으면 새 Trip 생성.
    private func resolveOrCreateTrip(
        for candidate: TripCandidate,
        fallbackName: String
    ) throws -> Trip {
        let candidateIds = Set(candidate.photos.map(\.assetLocalId))
        guard !candidateIds.isEmpty else {
            let trip = Trip(name: fallbackName, startDate: candidate.startDate, endDate: candidate.endDate)
            context.insert(trip)
            return trip
        }

        let existingTrips = try context.fetch(FetchDescriptor<Trip>())
        var best: (trip: Trip, overlap: Double)?
        for trip in existingTrips {
            let tripIds = Set(trip.days.flatMap { $0.photos.map(\.assetLocalId) })
            guard !tripIds.isEmpty else { continue }
            let intersection = tripIds.intersection(candidateIds).count
            let overlap = Double(intersection) / Double(candidateIds.count)
            if best == nil || overlap > best!.overlap {
                best = (trip, overlap)
            }
        }

        if let best, best.overlap >= 0.5 {
            return best.trip
        }

        let trip = Trip(name: fallbackName, startDate: candidate.startDate, endDate: candidate.endDate)
        context.insert(trip)
        return trip
    }

    /// B3 — Trip이 영속화된 후, 각 Day의 사진들을 SceneGrouping에 통과시켜 Scene 행을 생성.
    /// `featurePrintDistance` closure는 두 assetLocalId 쌍에 대한 Vision 거리값(또는 nil)을 반환.
    /// nil이면 그 페어는 다른 Scene으로 간주 (안전: AND 규칙을 절대 통과 못함).
    /// 멱등성: ≥2 photos 그룹만 Scene으로 만든다 (UserSettings.showSinglePhotoAsScene 기본 OFF).
    /// **사용자 수정 Scene 보존 (7차 라운드)**: `userModifiedAt != nil`인 Scene과 그 멤버는 B3 대상에서 제외하고 그대로 둠.
    func generateScenes(
        for trip: Trip,
        candidateMetadata: [PhotoMetadata],
        featurePrintDistance: (String, String) -> Float?
    ) throws {
        for day in trip.days {
            // 사용자 수정 Scene의 멤버는 lock — B3 후보에서 제외.
            let lockedPhotoIds = Set(
                day.scenes
                    .filter { $0.userModifiedAt != nil }
                    .flatMap { $0.photos.map(\.assetLocalId) }
            )

            // 자동 Scene만 청소 (사용자 수정 Scene은 유지).
            for scene in Array(day.scenes) where scene.userModifiedAt == nil {
                context.delete(scene)
            }

            let metas = day.photos.compactMap { p -> PhotoMetadata? in
                guard !lockedPhotoIds.contains(p.assetLocalId) else { return nil }
                return candidateMetadata.first(where: { $0.assetLocalId == p.assetLocalId })
            }
            guard metas.count >= 2 else { continue }

            let groups = SceneGrouping.group(
                photos: metas,
                featurePrintDistance: { a, b in
                    featurePrintDistance(a.assetLocalId, b.assetLocalId) ?? .infinity
                }
            )

            for group in groups where group.count >= 2 {
                let scene = Scene(day: day)
                context.insert(scene)
                let photosInGroup = group.compactMap { meta in
                    day.photos.first(where: { $0.assetLocalId == meta.assetLocalId })
                }
                for photo in photosInGroup {
                    photo.scene = scene
                }
                scene.representativePhoto = Self.pickRepresentative(from: photosInGroup)
            }
        }
    }

    /// Scene 대표 사진 선정 정책:
    /// 1) `isFavorite == true`인 사진 중 가장 빠른 `capturedAt` 우선
    /// 2) 없으면 그룹 내 가장 빠른 `capturedAt`
    /// W4에서 ♥ 토글이 들어오면 UI 레이어가 동기로 `scene.representativePhoto = photo`를 호출 (persistence.md).
    static func pickRepresentative(from photos: [Photo]) -> Photo? {
        let favorites = photos.filter { $0.isFavorite }
        let pool = favorites.isEmpty ? photos : favorites
        return pool.min { $0.capturedAt < $1.capturedAt }
    }

    /// 같은 assetLocalId를 가진 Photo가 이미 있으면 그것을 반환, 없으면 새로 삽입.
    private func resolveOrInsert(meta: PhotoMetadata, day: Day) throws -> Photo {
        let key = meta.assetLocalId
        let descriptor = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.assetLocalId == key }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.day = day
            existing.capturedAt = meta.capturedAt
            existing.isMissing = false
            existing.lastVerifiedAt = .now
            return existing
        }
        let new = Photo(
            day: day,
            assetLocalId: meta.assetLocalId,
            capturedAt: meta.capturedAt
        )
        new.lastVerifiedAt = .now
        context.insert(new)
        return new
    }
}
