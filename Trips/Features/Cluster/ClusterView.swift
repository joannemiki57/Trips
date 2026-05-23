import SwiftUI

/// 중복/유사 클러스터 — 같은 Scene에 속한 사진들을 펼쳐 보여줌. mvp.md §6.
/// 길게 누르면 "Scene에서 빼기" 액션. 사진 탭 → Photo Detail.
struct ClusterView: View {
    let photo: Photo
    var loader: ThumbnailLoader

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var labelAlertPresented = false
    @State private var labelDraft: String = ""

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: TripsSpacing.s)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TripsSpacing.l) {
                summary
                if let scene = photo.scene {
                    LabelChipRow(
                        directLabels: scene.labels,
                        onAdd: {
                            labelDraft = ""
                            labelAlertPresented = true
                        },
                        onRemove: { label in
                            try? LabelStore.detach(label: label, from: scene, context: context)
                        }
                    )
                    SceneMemoEditor(scene: scene)
                }
                LazyVGrid(columns: columns, spacing: TripsSpacing.s) {
                    ForEach(scenePhotos) { p in
                        NavigationLink(value: PhotoNavigationTarget.detail(p)) {
                            PhotoThumbnailView(
                                photo: p,
                                loader: loader,
                                sideLength: 140,
                                showsSceneBadge: false
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if p.scene != nil {
                                Button {
                                    detach(p)
                                } label: {
                                    SwiftUI.Label(
                                        String(localized: "cluster.split"),
                                        systemImage: "rectangle.stack.badge.minus"
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(TripsSpacing.l)
        }
        .background(TripsColor.bg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            String(localized: "label.add.title"),
            isPresented: $labelAlertPresented
        ) {
            TextField(String(localized: "label.add.placeholder"), text: $labelDraft)
            Button(String(localized: "label.add.save")) {
                addDraftLabelToScene()
            }
            Button(String(localized: "label.add.cancel"), role: .cancel) {}
        }
    }

    private func addDraftLabelToScene() {
        guard let scene = photo.scene else { return }
        let trimmed = labelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let label = try LabelStore.findOrCreate(name: trimmed, context: context)
            try LabelStore.attach(label: label, to: scene, context: context)
        } catch {
            // silent
        }
    }

    private func detach(_ p: Photo) {
        try? SceneSplitter.split(photo: p, context: context)
        // 분리 후 Scene이 사라졌거나 마지막 멤버 1장만 남았으면 ClusterView도 빠져나간다.
        if photo.scene == nil || (photo.scene?.photos.count ?? 0) < 2 {
            dismiss()
        }
    }

    private var scenePhotos: [Photo] {
        if let scene = photo.scene {
            return scene.photos.sorted { $0.capturedAt < $1.capturedAt }
        }
        return [photo]
    }

    private var title: String {
        if photo.scene != nil {
            return String(localized: "cluster.title")
        }
        return String(localized: "cluster.title.single")
    }

    private var summary: some View {
        HStack(spacing: TripsSpacing.s) {
            Image(systemName: "square.stack.3d.up")
                .foregroundStyle(TripsColor.textSecondary)
            Text(String(localized: "cluster.summary \(scenePhotos.count)"))
                .font(TripsFont.body)
                .foregroundStyle(TripsColor.textSecondary)
        }
    }
}

/// Scene.memo 편집기. PhotoDetail의 메모 에디터와 같은 패턴 (onDisappear에서 저장).
private struct SceneMemoEditor: View {
    @Bindable var scene: Scene
    @Environment(\.modelContext) private var context
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: TripsSpacing.s) {
            Text(String(localized: "cluster.memo"))
                .font(TripsFont.body.weight(.semibold))
                .foregroundStyle(TripsColor.textPrimary)
            TextField(
                String(localized: "cluster.memo.placeholder"),
                text: $draft,
                axis: .vertical
            )
            .lineLimit(2...5)
            .padding(TripsSpacing.m)
            .background(TripsColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: TripsRadius.card))
        }
        .onAppear {
            draft = scene.memo ?? ""
        }
        .onDisappear {
            let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            scene.memo = trimmed.isEmpty ? nil : trimmed
            scene.userModifiedAt = .now
            try? context.save()
        }
    }
}
