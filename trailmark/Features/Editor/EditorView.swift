import SwiftUI
import ComposableArchitecture

struct EditorView: View {
    @Bindable var store: StoreOf<EditorStore>
    @State private var scrollTarget: ScrollTarget?
    @State private var profileStatsData: ProfileStatsData?
    @State private var scrollIndexHolder = ScrollIndexHolder()
    @State private var highlightedMilestoneId: Int64?

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            if let detail = store.trailDetail {
                VStack(spacing: 0) {
                    // Mini profile
                    MiniProfileWrapper(
                        trackPoints: detail.trackPoints,
                        milestones: store.milestones,
                        scrollIndexHolder: scrollIndexHolder,
                        onIndexSelected: { index in
                            scrollTarget = ScrollTarget(index: index, animated: false)
                        }
                    )

                    // Scrollable elevation profile + overlays
                    ZStack(alignment: .top) {
                        ScrollableElevationProfileView(
                            trackPoints: detail.trackPoints,
                            milestones: store.milestones,
                            editingMilestoneId: highlightedMilestoneId,
                            statsData: profileStatsData,
                            scrollTarget: $scrollTarget,
                            onScrollIndexChanged: { [scrollIndexHolder] index in
                                scrollIndexHolder.index = index
                                store.send(.elevationProfile(.scrollPositionChanged(index)))
                                store.send(.segmentPanel(.scrollIndexChanged(index)))
                            },
                            onMilestoneTapped: { milestone in
                                scrollTarget = ScrollTarget(index: milestone.pointIndex, animated: true)
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(350))
                                    highlightedMilestoneId = milestone.id
                                    try? await Task.sleep(for: .milliseconds(300))
                                    Haptic.medium.trigger()
                                    store.send(.elevationProfile(.milestoneTapped(milestone)))
                                }
                            }
                        )

                        // Overlays
                        HStack {
                            StatsOverlayWrapper(
                                scrollIndexHolder: scrollIndexHolder,
                                statsData: profileStatsData
                            )
                            Spacer()
                            DistanceOverlayWrapper(
                                scrollIndexHolder: scrollIndexHolder,
                                statsData: profileStatsData
                            )
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                        .allowsHitTesting(false)
                    }

                    // Segment panel
                    SegmentPanelView(
                        store: store.scope(state: \.segmentPanel, action: \.segmentPanel),
                        milestones: store.milestones,
                        statsData: profileStatsData,
                        onGoToMilestone: { milestone in
                            scrollTarget = ScrollTarget(index: milestone.pointIndex, animated: true)
                        }
                    )
                }
            } else {
                ProgressView()
                    .tint(TM.accent)
            }
        }
        .toolbar {
            ToolbarItem(placement: .title) {
                if let detail = store.trailDetail {
                    Text(detail.trail.name)
                }
            }
            ToolbarItem(placement: .subtitle) {
                if let detail = store.trailDetail {
                    TrailStatsView(distanceKm: detail.distKm, dPlus: detail.trail.dPlus)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text("PRO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(TM.accent, in: RoundedRectangle(cornerRadius: 4))
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Renommer le fichier", systemImage: "square.and.pencil") {
                        Haptic.light.trigger()
                        store.send(.trailMetadata(.renameButtonTapped))
                    }
                    Button("Supprimer le fichier", systemImage: "trash", role: .destructive) {
                        Haptic.warning.trigger()
                        store.send(.trailMetadata(.deleteTrailButtonTapped))
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .toolbarRole(.editor)
        .alert($store.scope(state: \.trailMetadata.alert, action: \.trailMetadata.alert))
        .alert(
            "Renommer le parcours",
            isPresented: Binding(
                get: { store.trailMetadata.isRenamingTrail },
                set: { if !$0 { store.send(.trailMetadata(.renameCancelled)) } }
            )
        ) {
            TextField("Nom du parcours", text: Binding(
                get: { store.trailMetadata.editedTrailName },
                set: { store.send(.trailMetadata(.binding(.set(\.editedTrailName, $0)))) }
            ))
            Button("Annuler", role: .cancel) {
                Haptic.light.trigger()
                store.send(.trailMetadata(.renameCancelled))
            }
            Button("Renommer") {
                Haptic.medium.trigger()
                store.send(.trailMetadata(.renameConfirmed))
            }
            .keyboardShortcut(.defaultAction)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
        .task(id: store.trailDetail?.trail.id) {
            if let detail = store.trailDetail {
                profileStatsData = ProfileStatsData(trackPoints: detail.trackPoints)
            }
        }
        .sheet(
            item: $store.scope(state: \.milestoneSheet, action: \.milestoneSheet)
        ) { sheetStore in
            MilestoneSheetView(store: sheetStore)
                .presentationDetents([.fraction(0.5), .large])
                .presentationBackground(TM.bgCard)
                .onDisappear {
                    highlightedMilestoneId = nil
                }
        }
        .fullScreenCover(
            item: $store.scope(state: \.paywall, action: \.paywall)
        ) { paywallStore in
            PaywallContainerView(store: paywallStore)
        }
    }
}

// MARK: - Isolated Wrapper Views

@Observable
@MainActor
final class ScrollIndexHolder {
    var index: Int = 0
}

private struct MiniProfileWrapper: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let scrollIndexHolder: ScrollIndexHolder
    let onIndexSelected: (Int) -> Void

    var body: some View {
        MiniProfileView(
            trackPoints: trackPoints,
            milestones: milestones,
            currentIndex: scrollIndexHolder.index,
            onIndexSelected: onIndexSelected
        )
    }
}

private struct StatsOverlayWrapper: View {
    let scrollIndexHolder: ScrollIndexHolder
    let statsData: ProfileStatsData?

    var body: some View {
        if let stats = statsData,
           scrollIndexHolder.index < stats.trackPoints.count {
            ElevationStatsOverlay(
                dPlus: stats.cumulativeDPlus[scrollIndexHolder.index],
                dMinus: stats.cumulativeDMinus[scrollIndexHolder.index]
            )
        }
    }
}

private struct DistanceOverlayWrapper: View {
    let scrollIndexHolder: ScrollIndexHolder
    let statsData: ProfileStatsData?

    var body: some View {
        if let stats = statsData,
           scrollIndexHolder.index < stats.trackPoints.count {
            let point = stats.trackPoints[scrollIndexHolder.index]
            HStack(spacing: 8) {
                DistanceView(meters: point.distance)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.5, height: 16)

                HStack(spacing: 4) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TM.textTertiary)
                    Text("\(Int(point.elevation))")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.textSecondary)
                    Text("M")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
    }
}

// MARK: - Preview Helpers

@MainActor
private enum PreviewData {
    static var trackPoints: [TrackPoint] {
        do {
            let (parsedPoints, _) = try GPXParser.parseFromBundle(resource: "gpx_preview")
            return parsedPoints.enumerated().map { index, point in
                TrackPoint(
                    id: Int64(index + 1),
                    trailId: 1,
                    index: index,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    elevation: point.elevation,
                    distance: point.distance
                )
            }
        } catch {
            return []
        }
    }

    static var trail: Trail {
        let points = trackPoints
        let distance = points.last?.distance ?? 0
        let dPlus = calculateDPlus(points: points)
        return Trail(id: 1, name: "Thou Verdun", createdAt: Date(), distance: distance, dPlus: dPlus)
    }

    private static func calculateDPlus(points: [TrackPoint]) -> Int {
        var dPlus = 0.0
        for i in 1..<points.count {
            let delta = points[i].elevation - points[i-1].elevation
            if delta > 0 { dPlus += delta }
        }
        return Int(dPlus)
    }

    static func milestones(from points: [TrackPoint]) -> [Milestone] {
        guard points.count > 500 else { return [] }
        return [
            Milestone(id: 1, trailId: 1, pointIndex: 200, latitude: points[200].latitude, longitude: points[200].longitude, elevation: points[200].elevation, distance: points[200].distance, type: .montee, message: "Début de la montée vers le Mont Thou", name: "Montée Thou"),
            Milestone(id: 2, trailId: 1, pointIndex: 500, latitude: points[500].latitude, longitude: points[500].longitude, elevation: points[500].elevation, distance: points[500].distance, type: .info, message: "Sommet du Mont Thou, belle vue !", name: "Mont Thou"),
        ]
    }
}

private struct EditorPreviewWrapper: View {
    let milestones: [Milestone]

    var body: some View {
        NavigationStack {
            Color.clear
                .navigationDestination(isPresented: .constant(true)) {
                    let points = PreviewData.trackPoints
                    let ms = milestones.isEmpty ? [] : PreviewData.milestones(from: points)

                    EditorView(
                        store: Store(
                            initialState: {
                                var state = EditorStore.State(trailId: 1)
                                state.trailDetail = TrailDetail(trail: PreviewData.trail, trackPoints: points, milestones: ms)
                                state.milestones = ms
                                state.originalMilestones = ms
                                return state
                            }()
                        ) {
                            EditorStore()
                        }
                    )
                }
        }
    }
}

#Preview("Editor - With Milestones") {
    EditorPreviewWrapper(milestones: PreviewData.milestones(from: PreviewData.trackPoints))
}

#Preview("Editor - Empty Milestones") {
    EditorPreviewWrapper(milestones: [])
}
