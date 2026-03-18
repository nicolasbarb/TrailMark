import SwiftUI
import ComposableArchitecture

@Observable
@MainActor
final class ScrollIndexHolder {
    var index: Int = 0
}

struct ElevationProfileView: View {
    @Bindable var store: StoreOf<ElevationProfileFeature>
    @State private var scrollTarget: ScrollTarget?
    @State private var profileStatsData: ProfileStatsData?
    @State private var scrollIndexHolder = ScrollIndexHolder()
    @State private var highlightedMilestoneId: Int64?

    var body: some View {
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

                // Scrollable profile with overlays
                ZStack(alignment: .top) {
                    ScrollableElevationProfileView(
                        trackPoints: detail.trackPoints,
                        milestones: store.milestones,
                        editingMilestoneId: highlightedMilestoneId,
                        statsData: profileStatsData,
                        scrollTarget: $scrollTarget,
                        onScrollIndexChanged: { [scrollIndexHolder] index in
                            scrollIndexHolder.index = index
                            store.send(.scrollPositionChanged(index))
                        },
                        onMilestoneTapped: { milestone in
                            scrollTarget = ScrollTarget(index: milestone.pointIndex, animated: true)
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(350))
                                highlightedMilestoneId = milestone.id
                                try? await Task.sleep(for: .milliseconds(300))
                                Haptic.medium.trigger()
                                store.send(.milestoneTapped(milestone))
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
            }
            .task(id: detail.trail.id) {
                profileStatsData = ProfileStatsData(trackPoints: detail.trackPoints)
            }
        }
    }
}

// MARK: - Isolated Wrappers

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

// MARK: - Preview

#Preview("Elevation Profile") {
    ElevationProfileView(
        store: Store(
            initialState: {
                var state = ElevationProfileFeature.State()
                // Preview data will be loaded via @Shared
                return state
            }()
        ) {
            ElevationProfileFeature()
        }
    )
}