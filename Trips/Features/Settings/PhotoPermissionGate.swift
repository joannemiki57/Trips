import SwiftUI
import UIKit

/// C4 LOCKED — 권한 미허용 시 안내 + Settings 딥링크. 어떤 화면에서도 게이트로 끼울 수 있음.
struct PhotoPermissionGate<Content: View>: View {
    @State private var authorizer = PhotoLibraryAuthorizer()
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if authorizer.canRead {
                content()
            } else {
                permissionPlaceholder
            }
        }
        .task {
            await authorizer.requestAccessIfNeeded()
        }
        .onAppear {
            authorizer.refresh()
        }
    }

    private var permissionPlaceholder: some View {
        VStack(spacing: TripsSpacing.l) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(TripsColor.textSecondary)

            Text(String(localized: "permission.photos.denied.title"))
                .font(TripsFont.title)
                .foregroundStyle(TripsColor.textPrimary)

            Text(String(localized: "permission.photos.denied.body"))
                .font(TripsFont.body)
                .foregroundStyle(TripsColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TripsSpacing.xl)

            Button {
                openSettings()
            } label: {
                Text(String(localized: "permission.photos.openSettings"))
                    .font(TripsFont.body.weight(.semibold))
                    .padding(.horizontal, TripsSpacing.xl)
                    .padding(.vertical, TripsSpacing.m)
                    .background(TripsColor.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: TripsRadius.button))
            }
        }
        .padding(TripsSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TripsColor.bg)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
