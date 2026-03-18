import SwiftUI
import ComposableArchitecture

struct SegmentPanelView: View {
    @Bindable var store: StoreOf<SegmentPanelStore>
    let milestones: [Milestone]
    let statsData: ProfileStatsData?
    var onGoToMilestone: ((Milestone) -> Void)?

    private var currentSegment: ProfileStatsData.SegmentData? {
        guard let stats = statsData else { return nil }
        let idx = store.currentScrollIndex
        guard idx < stats.segmentIndices.count else { return nil }
        let segmentIdx = stats.segmentIndices[idx]
        guard segmentIdx < stats.segments.count else { return nil }
        return stats.segments[segmentIdx]
    }

    var body: some View {
        if let segment = currentSegment {
            VStack(spacing: 8) {
                // Ligne 1 : Type + bouton liste
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: segment.type.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(segment.type.color)
                        Text(segment.type.label)
                            .font(.system(.title3, weight: .bold))
                            .foregroundStyle(TM.textPrimary)
                    }

                    Spacer()

                    Button {
                        store.send(.listMilestonesTapped)
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(milestones.isEmpty ? TM.textTertiary : TM.textPrimary)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular, in: .circle)
                    }
                    .disabled(milestones.isEmpty)
                    .overlay(alignment: .topTrailing) {
                        if !milestones.isEmpty {
                            Text("\(milestones.count)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(segment.type.color, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }

                // Ligne 2 : Distance + dénivelé + bouton ajouter
                HStack(alignment: .center) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Distance")
                                .font(.caption2)
                                .foregroundStyle(TM.textTertiary)
                            Text(formatDistance(segment.distance))
                                .font(.system(.title3, design: .monospaced, weight: .bold))
                                .foregroundStyle(TM.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Dénivelé")
                                .font(.caption2)
                                .foregroundStyle(TM.textTertiary)
                            Text("\(segment.type == .descente ? "-" : "+")\(segment.elevationChange) m")
                                .font(.system(.title3, design: .monospaced, weight: .bold))
                                .foregroundStyle(TM.textPrimary)
                        }
                    }

                    Spacer()

                    Button {
                        Haptic.medium.trigger()
                        store.send(.addMilestoneTapped)
                    } label: {
                        Image("custom.flag.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(TM.accent, in: Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .sheet(item: $store.scope(state: \.milestoneList, action: \.milestoneList)) { listStore in
                MilestoneListView(
                    store: listStore,
                    milestones: milestones,
                    onGoToMilestone: onGoToMilestone
                )
                .presentationDetents([.medium, .large], selection: .constant(.large))
                .presentationBackground(TM.bgCard)
            }
        }
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return "\(Int(distance))m"
        }
    }
}

// MARK: - Preview

#Preview("Segment Panel") {
    VStack {
        Spacer()
        SegmentPanelView(
            store: Store(
                initialState: SegmentPanelStore.State()
            ) {
                SegmentPanelStore()
            },
            milestones: [],
            statsData: nil
        )
    }
    .background(TM.bgPrimary)
}
