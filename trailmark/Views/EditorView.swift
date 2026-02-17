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
                    tabPicker
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
        .toolbar {
            ToolbarItem(placement: .title) {
                if let detail = store.trailDetail {
                    Text(detail.trail.name)
                }
            }
            ToolbarItem(placement: .subtitle) {
                if let detail = store.trailDetail {
                    HStack(spacing: 4) {
                        Text(detail.distKm)
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(TM.textSecondary)
                        Text("km")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(TM.textMuted)
                        Text("·")
                            .foregroundStyle(TM.textMuted)
                        Text("\(detail.trail.dPlus)")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(TM.textSecondary)
                        Text("m+")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(TM.textMuted)
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sauvegarder", systemImage: "checkmark") {
                    store.send(.saveButtonTapped)
                }
            }
        }
        .toolbarRole(.editor)
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

    // MARK: - Tab Picker

    private var tabPicker: some View {
        VStack(spacing: 0) {
            Picker("Onglet", selection: $store.selectedTab.sending(\.tabSelected)) {
                Text("🗺 Carte")
                    .tag(EditorFeature.State.Tab.map)
                Text("📍 Jalons" + (store.milestones.isEmpty ? "" : " (\(store.milestones.count))"))
                    .tag(EditorFeature.State.Tab.milestones)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle()
                .fill(TM.bgTertiary)
                .frame(height: 1)
        }
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

// MARK: - Preview Helpers

private enum PreviewData {
    /// Génère des TrackPoints simulant un parcours de trail réaliste
    static func generateTrackPoints(count: Int = 200) -> [TrackPoint] {
        // Point de départ : Col du Galibier (Alpes françaises)
        let startLat = 45.0641
        let startLon = 6.4078
        var points: [TrackPoint] = []
        var cumulativeDistance: Double = 0

        for i in 0..<count {
            let progress = Double(i) / Double(count - 1)

            // Simuler un parcours en boucle
            let angle = progress * 2 * .pi
            let radius = 0.015 // ~1.5km de rayon

            let lat = startLat + sin(angle) * radius
            let lon = startLon + cos(angle) * radius * 1.3

            // Profil d'élévation réaliste : montée puis descente
            let elevation: Double
            if progress < 0.4 {
                // Montée
                elevation = 2100 + (progress / 0.4) * 400
            } else if progress < 0.6 {
                // Plateau sommital
                elevation = 2500 + sin(progress * 20) * 30
            } else {
                // Descente
                elevation = 2500 - ((progress - 0.6) / 0.4) * 400
            }

            // Distance cumulative (~15km total)
            if i > 0 {
                cumulativeDistance += 15000 / Double(count - 1)
            }

            points.append(TrackPoint(
                id: Int64(i + 1),
                trailId: 1,
                index: i,
                latitude: lat,
                longitude: lon,
                elevation: elevation,
                distance: cumulativeDistance
            ))
        }
        return points
    }

    static let trail = Trail(
        id: 1,
        name: "Col du Galibier",
        createdAt: Date(),
        distance: 15000,
        dPlus: 450,
        trailColor: .orange
    )

    static var trackPoints: [TrackPoint] {
        generateTrackPoints()
    }

    static func milestones(from points: [TrackPoint]) -> [Milestone] {
        [
            Milestone(
                id: 1,
                trailId: 1,
                pointIndex: 20,
                latitude: points[20].latitude,
                longitude: points[20].longitude,
                elevation: points[20].elevation,
                distance: points[20].distance,
                type: .montee,
                message: "Début de la montée, gardez un rythme régulier",
                name: "Départ montée"
            ),
            Milestone(
                id: 2,
                trailId: 1,
                pointIndex: 80,
                latitude: points[80].latitude,
                longitude: points[80].longitude,
                elevation: points[80].elevation,
                distance: points[80].distance,
                type: .ravito,
                message: "Ravitaillement dans 200 mètres, eau et barres",
                name: "Ravito Col"
            ),
            Milestone(
                id: 3,
                trailId: 1,
                pointIndex: 110,
                latitude: points[110].latitude,
                longitude: points[110].longitude,
                elevation: points[110].elevation,
                distance: points[110].distance,
                type: .danger,
                message: "Attention, passage technique avec pierrier",
                name: nil
            ),
            Milestone(
                id: 4,
                trailId: 1,
                pointIndex: 140,
                latitude: points[140].latitude,
                longitude: points[140].longitude,
                elevation: points[140].elevation,
                distance: points[140].distance,
                type: .descente,
                message: "Descente rapide, attention aux genoux",
                name: "Descente finale"
            )
        ]
    }

    static var trailDetail: TrailDetail {
        let points = trackPoints
        return TrailDetail(
            trail: trail,
            trackPoints: points,
            milestones: milestones(from: points)
        )
    }
}

private struct EditorPreviewWrapper: View {
    let tab: EditorFeature.State.Tab
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
                                var state = EditorFeature.State(trailId: 1)
                                state.trailDetail = TrailDetail(
                                    trail: PreviewData.trail,
                                    trackPoints: points,
                                    milestones: ms
                                )
                                state.milestones = ms
                                state.selectedTab = tab
                                return state
                            }()
                        ) {
                            EditorFeature()
                        }
                    )
                }
        }
    }
}

#Preview("Editor - Map Tab") {
    EditorPreviewWrapper(tab: .map, milestones: PreviewData.milestones(from: PreviewData.trackPoints))
}

#Preview("Editor - Milestones Tab") {
    EditorPreviewWrapper(tab: .milestones, milestones: PreviewData.milestones(from: PreviewData.trackPoints))
}

#Preview("Editor - Empty Milestones") {
    EditorPreviewWrapper(tab: .milestones, milestones: [])
}

#Preview("Milestone Sheet") {
    MilestoneSheetView(
        store: Store(
            initialState: MilestoneSheetFeature.State(
                editingMilestone: nil,
                pointIndex: 50,
                latitude: 45.0641,
                longitude: 6.4078,
                elevation: 2350,
                distance: 3500,
                selectedType: .montee,
                message: "",
                name: ""
            )
        ) {
            MilestoneSheetFeature()
        }
    )
    .presentationBackground(TM.bgCard)
}
