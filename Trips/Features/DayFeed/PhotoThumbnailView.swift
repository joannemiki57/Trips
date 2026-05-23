import SwiftUI
import UIKit

/// 그리드 셀 — 정사각형 썸네일. 같은 Scene 묶음을 시각적으로 알리기 위해 우측 상단에 작은 배지 표시.
struct PhotoThumbnailView: View {
    let photo: Photo
    var loader: ThumbnailLoader
    var sideLength: CGFloat
    /// Scene 묶음 개수 배지를 그릴지. Cluster 내부처럼 모든 사진이 같은 Scene일 땐 false.
    var showsSceneBadge: Bool = true

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(TripsColor.surface)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(TripsColor.textSecondary)
                    }
                }
                .frame(width: sideLength, height: sideLength)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    if photo.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TripsColor.accent)
                            .shadow(color: .black.opacity(0.4), radius: 2)
                            .padding(6)
                    }
                }
            if showsSceneBadge {
                sceneBadge
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TripsRadius.chip))
        .task(id: photo.id) {
            image = await loader.thumbnail(
                assetLocalId: photo.assetLocalId,
                size: CGSize(width: sideLength, height: sideLength)
            )
        }
    }

    @ViewBuilder
    private var sceneBadge: some View {
        if let scene = photo.scene, scene.photos.count > 1 {
            Text("\(scene.photos.count)")
                .font(TripsFont.captionSmall.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(4)
        }
    }
}
