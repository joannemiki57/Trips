import Testing
import Foundation
import SwiftData
@testable import Trips

@Suite("LabelStore · CRUD + Photo.allLabels union")
@MainActor
struct LabelStoreTests {

    private func freshContext() throws -> ModelContext {
        let container = try TripsModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: comps)!
    }

    private func seedPhoto(ctx: ModelContext) throws -> Photo {
        let trip = Trip(name: "T", startDate: date(2026, 5, 1), endDate: date(2026, 5, 1))
        ctx.insert(trip)
        let day = Day(date: date(2026, 5, 1), trip: trip)
        ctx.insert(day)
        let p = Photo(day: day, assetLocalId: "p1", capturedAt: date(2026, 5, 1))
        ctx.insert(p)
        try ctx.save()
        return p
    }

    @Test("findOrCreate — 같은 이름은 같은 인스턴스 반환 (case-insensitive)")
    func findOrCreateDeduplicates() throws {
        let ctx = try freshContext()
        let a = try LabelStore.findOrCreate(name: "Food", context: ctx)
        let b = try LabelStore.findOrCreate(name: "food", context: ctx)
        let c = try LabelStore.findOrCreate(name: "  Food  ", context: ctx)
        #expect(a.persistentModelID == b.persistentModelID)
        #expect(a.persistentModelID == c.persistentModelID)
        let labels = try ctx.fetch(FetchDescriptor<Label>())
        #expect(labels.count == 1)
    }

    @Test("findOrCreate — 새 이름이면 새 Label 생성 (.userDefined 기본)")
    func findOrCreateInsertsNew() throws {
        let ctx = try freshContext()
        let label = try LabelStore.findOrCreate(name: "View", context: ctx)
        #expect(label.name == "View")
        #expect(label.source == .userDefined)
    }

    @Test("Photo에 attach — labels에 추가, 중복 attach는 no-op")
    func attachToPhoto() throws {
        let ctx = try freshContext()
        let photo = try seedPhoto(ctx: ctx)
        let label = try LabelStore.findOrCreate(name: "Food", context: ctx)
        try LabelStore.attach(label: label, to: photo, context: ctx)
        try LabelStore.attach(label: label, to: photo, context: ctx)  // duplicate
        #expect(photo.labels.count == 1)
    }

    @Test("Photo에서 detach — labels에서 제거하고 Label 행 자체는 살아있음")
    func detachFromPhoto() throws {
        let ctx = try freshContext()
        let photo = try seedPhoto(ctx: ctx)
        let label = try LabelStore.findOrCreate(name: "Food", context: ctx)
        try LabelStore.attach(label: label, to: photo, context: ctx)
        try LabelStore.detach(label: label, from: photo, context: ctx)
        #expect(photo.labels.isEmpty)
        // Label 행은 살아있음 (다른 사진에 attach 가능하도록)
        #expect(try ctx.fetch(FetchDescriptor<Label>()).count == 1)
    }

    @Test("Photo.allLabels — Photo 직접 라벨 ∪ Scene 라벨 (중복 제거)")
    func allLabelsUnion() throws {
        let ctx = try freshContext()
        let photo = try seedPhoto(ctx: ctx)
        let scene = Scene(day: photo.day!)
        ctx.insert(scene)
        photo.scene = scene

        let food = try LabelStore.findOrCreate(name: "Food", context: ctx)
        let view = try LabelStore.findOrCreate(name: "View", context: ctx)
        let people = try LabelStore.findOrCreate(name: "People", context: ctx)

        try LabelStore.attach(label: food, to: photo, context: ctx)
        try LabelStore.attach(label: view, to: scene, context: ctx)
        try LabelStore.attach(label: people, to: photo, context: ctx)
        try LabelStore.attach(label: people, to: scene, context: ctx)  // 중복

        let names = Set(photo.allLabels.map(\.name))
        #expect(names == ["Food", "View", "People"])
    }

    @Test("Scene에 attach/detach")
    func attachAndDetachOnScene() throws {
        let ctx = try freshContext()
        let photo = try seedPhoto(ctx: ctx)
        let scene = Scene(day: photo.day!)
        ctx.insert(scene)
        let label = try LabelStore.findOrCreate(name: "View", context: ctx)

        try LabelStore.attach(label: label, to: scene, context: ctx)
        #expect(scene.labels.count == 1)
        try LabelStore.detach(label: label, from: scene, context: ctx)
        #expect(scene.labels.isEmpty)
    }

    @Test("빈 이름·공백만은 findOrCreate에서 거부")
    func emptyNameRejected() throws {
        let ctx = try freshContext()
        #expect(throws: LabelStore.Error.self) {
            try LabelStore.findOrCreate(name: "", context: ctx)
        }
        #expect(throws: LabelStore.Error.self) {
            try LabelStore.findOrCreate(name: "   ", context: ctx)
        }
    }
}
