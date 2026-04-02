import SwiftUI

struct TrailCard: View {
    let item: TrailListItem
    let isLocked: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onStart: () -> Void
    let onUnlock: () -> Void

    private var trail: Trail { item.trail }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: name + date
            HStack {
                Text(trail.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TM.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()

                Text(trail.createdAtDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(TM.textMuted)
            }

            // Elevation profile — grows when expanded
            if !item.trackPoints.isEmpty {
                ZStack {
                    ElevationProfilePreview(
                        trackPoints: item.trackPoints,
                        milestones: item.milestones
                    )
                    .frame(height: 60)
                    .clipShape(.rect(cornerRadius: 8))

                    if isLocked {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)

                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.title3)
                                .foregroundStyle(TM.textMuted)
                            ProBadge()
                        }
                    }
                }
            }

            // Stats row
            HStack(spacing: 0) {
                statItem(
                    value: String(format: "%.1f", trail.distance / 1000),
                    unit: "km"
                )

                Text("·")
                    .font(.caption2)
                    .foregroundStyle(TM.textMuted)
                    .padding(.horizontal, 6)

                statItem(
                    value: "\(trail.dPlus)",
                    unit: String(localized: "trailList.elevationGain")
                )

                Text("·")
                    .font(.caption2)
                    .foregroundStyle(TM.textMuted)
                    .padding(.horizontal, 6)

                statItem(
                    value: "\(item.milestoneCount)",
                    unit: String(localized: "trailList.milestones")
                )

                Spacer()
            }
            .opacity(isLocked ? 0.5 : 1)

            // Expandable buttons with stagger
            if isExpanded {
                if isLocked {
                    Button {
                        onUnlock()
                    } label: {
                        Label {
                            Text("common.unlockWithPro")
                                .font(.caption.weight(.medium))
                        } icon: {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                        }
                    }
                    .primaryButton(size: .regular, width: .flexible, shape: .roundedRectangle(radius: 10))
                    .transition(.move(edge: .top).combined(with: .blurReplace))
                } else {
                    HStack(spacing: 8) {
                        Button {
                            onEdit()
                        } label: {
                            Label {
                                Text("common.edit")
                                    .font(.caption.weight(.medium))
                            } icon: {
                                Image(systemName: "pencil")
                                    .font(.caption2)
                            }
                        }
                        .secondaryButton(size: .regular, width: .flexible, shape: .roundedRectangle(radius: 10))

                        Button {
                            onStart()
                        } label: {
                            Label {
                                Text("trailList.startButton")
                                    .font(.caption.weight(.medium))
                            } icon: {
                                Image(systemName: "play.fill")
                                    .font(.caption2)
                            }
                        }
                        .primaryButton(size: .regular, width: .flexible, shape: .roundedRectangle(radius: 10))
                    }
                    .transition(.move(edge: .top).combined(with: .blurReplace))
                }
            }
        }
        .padding(16)
        .background(TM.bgSecondary)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isExpanded ? TM.accent.opacity(0.4) : TM.border.opacity(0.3),
                    lineWidth: isExpanded ? 1.5 : 0.5
                )
        )
        .onTapGesture {
            onTap()
        }
    }

    private func statItem(value: String, unit: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(TM.textPrimary)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(TM.textMuted)
        }
    }
}
