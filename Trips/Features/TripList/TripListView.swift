import SwiftUI
import SwiftData

/// 메인 화면 — 임포트된 Trip들의 카드 리스트. mvp.md §6.2 Trips.
/// 빈 상태에서 사진 라이브러리 스캔을 시작할 수 있고, 결과가 들어오면 카드로 표시.
/// W2 범위 — 재스캔/병합/분할 등 운영 액션은 W3 이후.
struct TripListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Trip.startDate, order: .reverse)
    private var trips: [Trip]

    @State private var importPhase: ImportPhase = .idle
    @State private var thumbnailLoader = ThumbnailLoader()

    @State private var renamingTrip: Trip?
    @State private var renameDraft: String = ""
    @State private var renameAlertPresented: Bool = false

    enum ImportPhase: Equatable {
        case idle
        case running
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TripsColor.bg)
            .navigationTitle(String(localized: "app.name"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !trips.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await runImport() }
                        } label: {
                            if importPhase == .running {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(importPhase == .running)
                        .accessibilityLabel(String(localized: "triplist.rescan"))
                    }
                }
            }
            .task {
                try? TripImportService.purgeEmptyTrips(context: context)
            }
            .alert(
                String(localized: "triplist.rename.title"),
                isPresented: $renameAlertPresented,
                presenting: renamingTrip
            ) { trip in
                TextField(
                    String(localized: "triplist.rename.placeholder"),
                    text: $renameDraft
                )
                Button(String(localized: "triplist.rename.save")) {
                    commitRename(trip: trip)
                }
                Button(String(localized: "triplist.rename.cancel"), role: .cancel) {}
            }
        }
    }

    private func startRename(_ trip: Trip) {
        renamingTrip = trip
        renameDraft = trip.name
        renameAlertPresented = true
    }

    private func commitRename(trip: Trip) {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        trip.name = trimmed
        try? context.save()
    }

    private var emptyState: some View {
        VStack(spacing: TripsSpacing.xl) {
            Spacer()
            Image(systemName: "suitcase")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(TripsColor.textSecondary)
            VStack(spacing: TripsSpacing.s) {
                Text(String(localized: "triplist.empty.title"))
                    .font(TripsFont.title)
                    .foregroundStyle(TripsColor.textPrimary)
                Text(String(localized: "triplist.empty.body"))
                    .font(TripsFont.body)
                    .foregroundStyle(TripsColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TripsSpacing.xl)
            }
            scanButton
            if case .failed(let msg) = importPhase {
                Text(msg)
                    .font(TripsFont.caption)
                    .foregroundStyle(TripsColor.warning)
                    .padding(.horizontal, TripsSpacing.xl)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(TripsSpacing.xl)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: TripsSpacing.l) {
                ForEach(trips) { trip in
                    NavigationLink(value: trip) {
                        TripCardView(
                            trip: trip,
                            loader: thumbnailLoader,
                            onRename: { startRename(trip) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(TripsSpacing.l)
        }
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(trip: trip, loader: thumbnailLoader)
        }
        .navigationDestination(for: PhotoNavigationTarget.self) { target in
            switch target {
            case .cluster(let photo):
                ClusterView(photo: photo, loader: thumbnailLoader)
            case .detail(let photo):
                PhotoDetailView(photo: photo, loader: thumbnailLoader)
            }
        }
    }

    private var scanButton: some View {
        Button {
            Task { await runImport() }
        } label: {
            HStack(spacing: TripsSpacing.s) {
                if importPhase == .running {
                    ProgressView()
                        .tint(.white)
                }
                Text(scanButtonLabel)
                    .font(TripsFont.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TripsSpacing.m)
            .background(importPhase == .running ? TripsColor.textSecondary : TripsColor.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: TripsRadius.button))
        }
        .disabled(importPhase == .running)
        .padding(.horizontal, TripsSpacing.xl)
    }

    private var scanButtonLabel: String {
        switch importPhase {
        case .idle, .failed:
            return String(localized: "triplist.empty.scanButton")
        case .running:
            return String(localized: "triplist.scanning")
        }
    }

    private func runImport() async {
        importPhase = .running
        do {
            let service = TripImportService(context: context)
            _ = try await service.run()
            importPhase = .idle
        } catch {
            importPhase = .failed(error.localizedDescription)
        }
    }
}
