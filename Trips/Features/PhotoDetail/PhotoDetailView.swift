import SwiftUI
import SwiftData
import UIKit

/// 사진 1장 상세 — 5차 라운드에서 v1 포함 확정. mvp.md §6.2.
/// 큰 이미지 + ♥ 토글 + 메모 입력 + 촬영 시각 메타. 메모/♥ 변경은 onDisappear에서 명시 저장.
struct PhotoDetailView: View {
    @Bindable var photo: Photo
    var loader: ThumbnailLoader

    @Environment(\.modelContext) private var context

    @State private var image: UIImage?
    @State private var draftMemo: String = ""
    @State private var labelAlertPresented = false
    @State private var labelDraft: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TripsSpacing.l) {
                photoArea
                metadataRow
                LabelChipRow(
                    directLabels: photo.labels,
                    inheritedLabels: inheritedSceneLabels,
                    onAdd: {
                        labelDraft = ""
                        labelAlertPresented = true
                    },
                    onRemove: { label in
                        try? LabelStore.detach(label: label, from: photo, context: context)
                    }
                )
                memoEditor
            }
            .padding(TripsSpacing.l)
        }
        .background(TripsColor.bg)
        .navigationTitle(String(localized: "photodetail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    try? FavoriteToggler.toggle(photo: photo, context: context)
                } label: {
                    Image(systemName: photo.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(photo.isFavorite ? TripsColor.accent : TripsColor.textSecondary)
                }
                .accessibilityLabel(String(localized: "photodetail.favorite"))
            }
        }
        .alert(
            String(localized: "label.add.title"),
            isPresented: $labelAlertPresented
        ) {
            TextField(String(localized: "label.add.placeholder"), text: $labelDraft)
            Button(String(localized: "label.add.save")) {
                addDraftLabel()
            }
            Button(String(localized: "label.add.cancel"), role: .cancel) {}
        }
        .onAppear {
            draftMemo = photo.memo ?? ""
        }
        .onDisappear {
            let trimmed = draftMemo.trimmingCharacters(in: .whitespacesAndNewlines)
            photo.memo = trimmed.isEmpty ? nil : trimmed
            try? context.save()
        }
    }

    /// Scene이 가진 라벨 중 Photo 자체엔 직접 없는 것들 — 회색 칩(상속 표시)으로 따로 보여줌.
    private var inheritedSceneLabels: [Label] {
        guard let sceneLabels = photo.scene?.labels, !sceneLabels.isEmpty else { return [] }
        let directIds = Set(photo.labels.map(\.persistentModelID))
        return sceneLabels.filter { !directIds.contains($0.persistentModelID) }
    }

    private func addDraftLabel() {
        let trimmed = labelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let label = try LabelStore.findOrCreate(name: trimmed, context: context)
            try LabelStore.attach(label: label, to: photo, context: context)
        } catch {
            // 빈 이름은 가드가 컷, 다른 에러는 silently fail (UI surface는 v1.1)
        }
    }

    private var photoArea: some View {
        ZStack {
            Rectangle()
                .fill(TripsColor.surface)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(TripsColor.textSecondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: TripsRadius.card))
        .task(id: photo.id) {
            let side = UIScreen.main.bounds.width - 2 * TripsSpacing.l
            image = await loader.thumbnail(
                assetLocalId: photo.assetLocalId,
                size: CGSize(width: side, height: side)
            )
        }
    }

    private var metadataRow: some View {
        HStack(spacing: TripsSpacing.s) {
            Image(systemName: "calendar")
                .foregroundStyle(TripsColor.textSecondary)
            Text(formattedCapturedAt)
                .font(TripsFont.caption)
                .foregroundStyle(TripsColor.textSecondary)
            Spacer()
            if photo.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(TripsColor.accent)
                    .font(TripsFont.caption)
            }
        }
    }

    private var memoEditor: some View {
        VStack(alignment: .leading, spacing: TripsSpacing.s) {
            Text(String(localized: "photodetail.memo"))
                .font(TripsFont.body.weight(.semibold))
                .foregroundStyle(TripsColor.textPrimary)
            TextField(
                String(localized: "photodetail.memo.placeholder"),
                text: $draftMemo,
                axis: .vertical
            )
            .lineLimit(3...8)
            .padding(TripsSpacing.m)
            .background(TripsColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: TripsRadius.card))
        }
    }

    private var formattedCapturedAt: String {
        photo.capturedAt.formatted(
            Date.FormatStyle()
                .month(.abbreviated)
                .day()
                .year(.defaultDigits)
                .hour()
                .minute()
        )
    }
}
