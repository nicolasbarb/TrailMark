import SwiftUI
import ComposableArchitecture

struct MilestoneListView: View {
    @Bindable var store: StoreOf<MilestoneListFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.milestones) { milestone in
                        Button {
                            Haptic.medium.trigger()
                            store.send(.milestoneTapped(milestone))
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: milestone.milestoneType.systemImage)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(milestone.milestoneType.color)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    if let name = milestone.name, !name.isEmpty {
                                        Text(name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(TM.textPrimary)
                                    }
                                    Text(milestone.milestoneType.label)
                                        .font(.caption)
                                        .foregroundStyle(TM.textTertiary)
                                }

                                Spacer()

                                Text(formatDistance(milestone.distance))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(TM.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        if milestone.id != store.milestones.last?.id {
                            Divider()
                                .padding(.leading, 54)
                        }
                    }
                }
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

#Preview("Milestone List") {
    MilestoneListView(
        store: Store(
            initialState: MilestoneListFeature.State()
        ) {
            MilestoneListFeature()
        }
    )
    .presentationBackground(TM.bgCard)
}