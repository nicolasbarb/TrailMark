import SwiftUI
import ComposableArchitecture
import MapKit

struct EditorView: View {
    @Bindable var store: StoreOf<EditorFeature>

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            if let detail = store.trailDetail {
                VStack(spacing: 0) {
                    editorHeader(detail: detail)
                    tabBar
                    tabContent(detail: detail)
                }
            } else {
                ProgressView()
                    .tint(TM.accent)
            }

            // Toast
            if store.showToast {
                VStack {
                    toastView
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring, value: store.showToast)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(
            item: $store.scope(state: \.milestoneSheet, action: \.milestoneSheet)
        ) { sheetStore in
            MilestoneSheetView(store: sheetStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(TM.bgCard)
        }
    }

    // MARK: - Header

    private func editorHeader(detail: TrailDetail) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back button
                Button {
                    store.send(.backTapped)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .foregroundStyle(TM.textSecondary)
                }

                // Logo and file info
                VStack(alignment: .leading, spacing: 2) {
                    Text("TrailMark")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.accent)
                    Text(detail.trail.name)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.textMuted)
                }

                Spacer()

                // Stats
                HStack(spacing: 4) {
                    Text(detail.distKm)
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.textPrimary)
                    Text("km")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.textMuted)
                    Text("\(detail.trail.dPlus)")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.textPrimary)
                    Text("m+")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.textMuted)
                }

                // Save button
                Button {
                    store.send(.saveButtonTapped)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.caption)
                        Text("Sauver")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(TM.accentGradient, in: RoundedRectangle(cornerRadius: 9))
                    .shadow(color: TM.accent.opacity(0.3), radius: 8, y: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Rectangle()
                .fill(TM.bgTertiary)
                .frame(height: 1)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(title: "🗺 Carte", tab: .map)
                tabButton(
                    title: "📍 Jalons" + (store.milestones.isEmpty ? "" : " (\(store.milestones.count))"),
                    tab: .milestones
                )
            }
            .padding(.horizontal, 16)

            Rectangle()
                .fill(TM.bgTertiary)
                .frame(height: 1)
        }
    }

    private func tabButton(title: String, tab: EditorFeature.State.Tab) -> some View {
        let isActive = store.selectedTab == tab

        return Button {
            store.send(.tabSelected(tab))
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? TM.accent : TM.textMuted)

                Rectangle()
                    .fill(isActive ? TM.accent : .clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(detail: TrailDetail) -> some View {
        switch store.selectedTab {
        case .map:
            mapTab(detail: detail)
        case .milestones:
            milestonesTab
        }
    }

    // MARK: - Map Tab

    private func mapTab(detail: TrailDetail) -> some View {
        VStack(spacing: 0) {
            TrailMapView(
                trackPoints: detail.trackPoints,
                milestones: store.milestones,
                cursorPointIndex: store.cursorPointIndex,
                trailColor: detail.trail.trailColor
            )

            ElevationProfileView(
                trackPoints: detail.trackPoints,
                milestones: store.milestones,
                cursorPointIndex: Binding(
                    get: { store.cursorPointIndex },
                    set: { store.send(.cursorMoved($0)) }
                ),
                onTap: { index in
                    store.send(.profileTapped(index))
                }
            )
            .frame(height: 170)
        }
    }

    // MARK: - Milestones Tab

    private var milestonesTab: some View {
        Group {
            if store.milestones.isEmpty {
                milestonesEmptyState
            } else {
                milestonesList
            }
        }
    }

    private var milestonesEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("📍")
                .font(.system(size: 32))

            Text("Aucun jalon")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TM.textSecondary)

            Text("Allez sur Carte et tapez\nle profil pour en ajouter")
                .font(.caption)
                .foregroundStyle(TM.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private var milestonesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.milestones.enumerated()), id: \.offset) { index, milestone in
                    milestoneRow(milestone: milestone, index: index)
                }
            }
        }
    }

    private func milestoneRow(milestone: Milestone, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                // Number badge
                Text("\(index + 1)")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(milestone.milestoneType.color, in: Circle())

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(milestone.milestoneType.icon) \(milestone.milestoneType.label.uppercased())")
                            .font(.caption2.weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(milestone.milestoneType.color)

                        if let name = milestone.name {
                            Text("— \(name)")
                                .font(.caption2)
                                .foregroundStyle(TM.textSecondary)
                        }
                    }

                    Text(milestone.message)
                        .font(.subheadline)
                        .foregroundStyle(TM.textPrimary)
                        .lineLimit(2)

                    Text("km \(String(format: "%.1f", milestone.distance / 1000)) · \(Int(milestone.elevation))m")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.textMuted)
                }

                Spacer()

                // Delete button
                Button {
                    store.send(.deleteMilestone(index))
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(TM.textMuted)
                        .padding(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                store.send(.editMilestone(milestone))
            }

            Rectangle()
                .fill(TM.bgSecondary)
                .frame(height: 1)
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(TM.success)
            Text("TrailMark sauvegardé !")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TM.success)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TM.success.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
        .padding(.top, 8)
    }
}

// MARK: - Milestone Sheet View

struct MilestoneSheetView: View {
    @Bindable var store: StoreOf<MilestoneSheetFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(store.isEditing ? "Modifier" : "Nouveau jalon")
                        .font(.headline)
                        .foregroundStyle(TM.textPrimary)

                    Spacer()

                    Button {
                        store.send(.dismissTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundStyle(TM.textMuted)
                    }
                }

                // Position
                Text("km \(String(format: "%.2f", store.distance / 1000)) · \(Int(store.elevation))m")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TM.textMuted)
                    .padding(.top, 4)

                // Type selector
                sectionLabel("TYPE")
                    .padding(.top, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(MilestoneType.allCases, id: \.self) { type in
                        typeButton(type)
                    }
                }
                .padding(.top, 8)

                // Message
                sectionLabel("MESSAGE TTS")
                    .padding(.top, 14)

                TextField("ex: Montée de 200m, marchez…", text: $store.message, axis: .vertical)
                    .lineLimit(3...5)
                    .font(.body)
                    .foregroundStyle(TM.textPrimary)
                    .padding(12)
                    .background(TM.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(TM.border, lineWidth: 1)
                    )
                    .padding(.top, 8)

                // Name
                sectionLabel("NOM (OPTIONNEL)")
                    .padding(.top, 14)

                TextField("ex: Col de la Croix", text: $store.name)
                    .font(.body)
                    .foregroundStyle(TM.textPrimary)
                    .padding(12)
                    .background(TM.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(TM.border, lineWidth: 1)
                    )
                    .padding(.top, 8)

                // Save button
                Button {
                    store.send(.saveButtonTapped)
                } label: {
                    Text(store.isEditing ? "Enregistrer" : "Ajouter")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TM.accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 16)
            }
            .padding(20)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(TM.textMuted)
    }

    private func typeButton(_ type: MilestoneType) -> some View {
        let isSelected = store.selectedType == type

        return Button {
            store.send(.typeSelected(type))
        } label: {
            VStack(spacing: 4) {
                Text(type.icon)
                    .font(.title3)
                Text(type.label)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? TM.textPrimary : TM.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? type.color.opacity(0.1) : TM.bgPrimary,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? type.color : TM.border, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    NavigationStack {
        EditorView(
            store: Store(initialState: EditorFeature.State(trailId: 1)) {
                EditorFeature()
            }
        )
    }
    .preferredColorScheme(.dark)
}
