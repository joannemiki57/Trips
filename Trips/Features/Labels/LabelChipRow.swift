import SwiftUI

/// 라벨 칩 + 추가 버튼 공용 컴포넌트. PhotoDetail + Cluster에서 동일 모양으로 사용.
/// `onAdd`: "추가" 버튼 탭 시 호출 — 호출자가 입력 alert를 띄우고 결과로 다시 `attach` 호출.
/// `onRemove`: 칩 long-press 컨텍스트 메뉴의 "삭제" 탭 시 호출.
struct LabelChipRow: View {
    /// 이 엔티티에 직접 붙은 라벨 — context menu로 삭제 가능
    let directLabels: [Label]
    /// 부모(Scene)에서 상속된 라벨 — 표시만, 삭제는 부모 화면에서
    var inheritedLabels: [Label] = []
    var onAdd: () -> Void
    var onRemove: (Label) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TripsSpacing.s) {
            Text(String(localized: "label.section.title"))
                .font(TripsFont.body.weight(.semibold))
                .foregroundStyle(TripsColor.textPrimary)
            FlowLayout(spacing: TripsSpacing.s) {
                ForEach(directLabels) { label in
                    chip(for: label, inherited: false)
                }
                ForEach(inheritedLabels) { label in
                    chip(for: label, inherited: true)
                }
                addButton
            }
        }
    }

    private func chip(for label: Label, inherited: Bool) -> some View {
        HStack(spacing: TripsSpacing.xs) {
            if inherited {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(label.name)
        }
        .font(TripsFont.caption.weight(.semibold))
        .padding(.horizontal, TripsSpacing.m)
        .padding(.vertical, TripsSpacing.xs)
        .background(inherited ? TripsColor.bg : TripsColor.surface)
        .foregroundStyle(inherited ? TripsColor.textSecondary : TripsColor.textPrimary)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(TripsColor.border, lineWidth: 1)
        )
        .contextMenu {
            if !inherited {
                Button(role: .destructive) {
                    onRemove(label)
                } label: {
                    SwiftUI.Label(
                        String(localized: "label.remove"),
                        systemImage: "tag.slash"
                    )
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            onAdd()
        } label: {
            HStack(spacing: TripsSpacing.xs) {
                Image(systemName: "plus")
                Text(String(localized: "label.add"))
            }
            .font(TripsFont.caption.weight(.semibold))
            .padding(.horizontal, TripsSpacing.m)
            .padding(.vertical, TripsSpacing.xs)
            .background(TripsColor.accent)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
    }
}

/// 간단한 줄바꿈 레이아웃. SwiftUI Layout 프로토콜로 가변 너비 칩을 알아서 다음 줄로 넘김.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = arrange(subviews: subviews, maxWidth: maxWidth)
        return CGSize(width: maxWidth.isFinite ? maxWidth : result.maxX, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arranged = arrange(subviews: subviews, maxWidth: bounds.width)
        for (subview, point) in zip(subviews, arranged.points) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> (points: [CGPoint], maxX: CGFloat, height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowMaxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowMaxX = max(rowMaxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (points, rowMaxX, y + rowHeight)
    }
}
