import SwiftUI
import ComposableArchitecture

// @Observable so wrapper views can react, but EditorProfileView body NEVER reads .index
@Observable
@MainActor
final class ScrollIndexHolder {
    var index: Int = 0
}

struct EditorProfileView: View {
    @Bindable var store: StoreOf<ElevationProfileStore>
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let statsData: ProfileStatsData?
    @Binding var scrollTarget: ScrollTarget?
    @Binding var highlightedMilestoneId: Int64?

    @State private var scrollIndexHolder = ScrollIndexHolder()

    var body: some View {
        VStack(spacing: 0) {
            // Mini profile
            MiniProfileWrapper(
                trackPoints: trackPoints,
                milestones: milestones,
                scrollIndexHolder: scrollIndexHolder,
                onIndexSelected: { index in
                    scrollTarget = ScrollTarget(index: index, animated: false)
                }
            )

            // Scrollable profile + overlays
            ZStack(alignment: .top) {
                ScrollableElevationProfileView(
                    trackPoints: trackPoints,
                    milestones: milestones,
                    editingMilestoneId: highlightedMilestoneId,
                    statsData: statsData,
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
                        statsData: statsData
                    )
                    Spacer()
                    AltitudeOverlayWrapper(
                        scrollIndexHolder: scrollIndexHolder,
                        statsData: statsData
                    )
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)
                .allowsHitTesting(false)
            }
        }
    }

    /// Current scroll index for external consumers (e.g., SegmentPanel)
    var currentScrollIndex: Int {
        scrollIndexHolder.index
    }
}

// MARK: - Isolated Wrapper Views

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

private struct AltitudeOverlayWrapper: View {
    let scrollIndexHolder: ScrollIndexHolder
    let statsData: ProfileStatsData?

    var body: some View {
        if let stats = statsData,
           scrollIndexHolder.index < stats.trackPoints.count {
            let point = stats.trackPoints[scrollIndexHolder.index]
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
    }
}

// MARK: - Preview

#Preview("Editor Profile") {
    EditorProfileView(
        store: Store(initialState: ElevationProfileStore.State()) {
            ElevationProfileStore()
        },
        trackPoints: [],
        milestones: [],
        statsData: nil,
        scrollTarget: .constant(nil),
        highlightedMilestoneId: .constant(nil)
    )
}
