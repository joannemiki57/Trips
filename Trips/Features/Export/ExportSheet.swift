import SwiftUI

/// Trip 상세에서 share 아이콘 누르면 올라오는 시트. mvp.md §5.5.
/// 두 액션: "Save as PDF" / "Save Favorites to Album".
struct ExportSheet: View {
    let trip: Trip
    let imageDataProvider: PhotoImageDataProvider

    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    @State private var isGenerating = false
    @State private var albumState: AlbumState = .idle
    @State private var errorMessage: String?

    enum AlbumState {
        case idle
        case saving
        case saved
    }

    private var hasFavorites: Bool {
        trip.days.contains { day in day.photos.contains { $0.isFavorite } }
    }

    var body: some View {
        VStack(spacing: TripsSpacing.l) {
            handle
            header

            if !hasFavorites {
                emptyState
            } else {
                pdfRow
                albumRow
                if let errorMessage {
                    Text(errorMessage)
                        .font(TripsFont.caption)
                        .foregroundStyle(TripsColor.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, TripsSpacing.l)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, TripsSpacing.l)
        .padding(.bottom, TripsSpacing.l)
        .background(TripsColor.bg)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Pieces

    private var handle: some View {
        Capsule()
            .fill(TripsColor.border)
            .frame(width: 36, height: 4)
            .padding(.top, TripsSpacing.s)
    }

    private var header: some View {
        VStack(spacing: TripsSpacing.xs) {
            Text(String(localized: "export.title"))
                .font(TripsFont.title)
                .foregroundStyle(TripsColor.textPrimary)
            Text(trip.name)
                .font(TripsFont.caption)
                .foregroundStyle(TripsColor.textSecondary)
        }
        .padding(.top, TripsSpacing.s)
    }

    private var emptyState: some View {
        VStack(spacing: TripsSpacing.s) {
            Image(systemName: "heart.slash")
                .font(.system(size: 28))
                .foregroundStyle(TripsColor.textSecondary)
            Text(String(localized: "export.empty"))
                .font(TripsFont.body)
                .foregroundStyle(TripsColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, TripsSpacing.xl)
    }

    private var pdfRow: some View {
        Group {
            if let pdfURL {
                ShareLink(item: pdfURL) {
                    row(
                        systemImage: "checkmark.circle.fill",
                        title: String(localized: "export.pdf.ready"),
                        subtitle: String(localized: "export.pdf.tapToShare"),
                        tint: TripsColor.success
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task { await generatePDF() }
                } label: {
                    row(
                        systemImage: isGenerating ? "hourglass" : "doc.richtext",
                        title: String(localized: "export.pdf.title"),
                        subtitle: isGenerating
                            ? String(localized: "export.pdf.generating")
                            : String(localized: "export.pdf.subtitle"),
                        tint: TripsColor.accent
                    )
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
        }
    }

    private var albumRow: some View {
        Button {
            Task { await saveToAlbum() }
        } label: {
            row(
                systemImage: albumIcon,
                title: String(localized: "export.album.title"),
                subtitle: albumSubtitle,
                tint: albumState == .saved ? TripsColor.success : TripsColor.accent
            )
        }
        .buttonStyle(.plain)
        .disabled(albumState == .saving || albumState == .saved)
    }

    private var albumIcon: String {
        switch albumState {
        case .idle: "photo.on.rectangle.angled"
        case .saving: "hourglass"
        case .saved: "checkmark.circle.fill"
        }
    }

    private var albumSubtitle: String {
        switch albumState {
        case .idle: String(localized: "export.album.subtitle")
        case .saving: String(localized: "export.album.saving")
        case .saved: String(localized: "export.album.saved")
        }
    }

    private func row(systemImage: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: TripsSpacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TripsFont.body.weight(.semibold))
                    .foregroundStyle(TripsColor.textPrimary)
                Text(subtitle)
                    .font(TripsFont.caption)
                    .foregroundStyle(TripsColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TripsColor.textSecondary)
        }
        .padding(TripsSpacing.m)
        .background(TripsColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func generatePDF() async {
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }

        let content = TripExportContent(trip: trip)
        let data = await TripPDFRenderer.render(content: content, provider: imageDataProvider)
        do {
            let url = try writeToTemp(data: data, filename: pdfFilename(for: trip))
            pdfURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveToAlbum() async {
        errorMessage = nil
        albumState = .saving
        do {
            try await TripAlbumWriter.saveFavorites(trip: trip)
            albumState = .saved
        } catch TripAlbumWriter.WriteError.writeAccessDenied {
            albumState = .idle
            errorMessage = String(localized: "export.album.denied")
        } catch {
            albumState = .idle
            errorMessage = error.localizedDescription
        }
    }

    private func writeToTemp(data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url)
        return url
    }

    private func pdfFilename(for trip: Trip) -> String {
        let safe = trip.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(safe).pdf"
    }
}
