import SwiftUI
import ComposableArchitecture

struct MilestoneListView: View {
    @Bindable var store: StoreOf<MilestoneListStore>
    let milestones: [Milestone]
    var onGoToMilestone: ((Milestone) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                        Button {
                            Haptic.medium.trigger()
                            onGoToMilestone?(milestone)
                            store.send(.milestoneTapped(milestone))
                        } label: {
                            MilestoneRow(milestone: milestone, index: index + 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Repères")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .sheet(
                item: $store.scope(state: \.milestoneSheet, action: \.milestoneSheet)
            ) { sheetStore in
                MilestoneSheetView(store: sheetStore)
            }
        }
    }
}

// MARK: - Milestone Row

private struct MilestoneRow: View {
    let milestone: Milestone
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            // Icône type dans un cercle coloré
            Image(systemName: milestone.milestoneType.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(milestone.milestoneType.color, in: Circle())

            // Infos
            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.name ?? milestone.milestoneType.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TM.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Km
                    Label(formatDistance(milestone.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(TM.textTertiary)

                    // Altitude
                    Label("\(Int(milestone.elevation)) m", systemImage: "mountain.2.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(TM.textTertiary)
                }
            }

            Spacer()

            // Numéro
            Text("#\(index)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(TM.textTertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TM.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
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

#Preview("Milestone List") {
    MilestoneListView(
        store: Store(
            initialState: MilestoneListStore.State()
        ) {
            MilestoneListStore()
        },
        milestones: [
            Milestone(id: 1, trailId: 1, pointIndex: 120, latitude: 45.06, longitude: 6.40, elevation: 850, distance: 1200, type: .climb, message: "Début de la montée", name: "Montée du Col"),
            Milestone(id: 2, trailId: 1, pointIndex: 350, latitude: 45.07, longitude: 6.41, elevation: 1420, distance: 3500, type: .descent, message: "Descente technique", name: "Descente Nord"),
            Milestone(id: 3, trailId: 1, pointIndex: 500, latitude: 45.08, longitude: 6.42, elevation: 980, distance: 5100, type: .aidStation, message: "Ravitaillement, prenez à gauche"),
            Milestone(id: 4, trailId: 1, pointIndex: 620, latitude: 45.09, longitude: 6.43, elevation: 1100, distance: 6800, type: .danger, message: "Passage technique exposé", name: "Crête"),
            Milestone(id: 5, trailId: 1, pointIndex: 800, latitude: 45.10, longitude: 6.44, elevation: 750, distance: 9200, type: .info, message: "Belle vue sur la vallée", name: "Belvédère"),
        ]
    )
    .presentationBackground(TM.bgCard)
}
