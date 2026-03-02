import SwiftUI
import ComposableArchitecture

struct EditorView: View {
    @Bindable var store: StoreOf<EditorFeature>

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            if let detail = store.trailDetail {
                VStack(spacing: 0) {
                    // Scrollable profile (50% height)
                    ScrollableElevationProfileView(
                        trackPoints: detail.trackPoints,
                        milestones: store.milestones,
                        scrolledPointIndex: Binding(
                            get: { store.scrolledPointIndex },
                            set: { store.send(.scrollPositionChanged($0)) }
                        )
                    )
                    .containerRelativeFrame(.vertical) { height, _ in height / 2 }

                    Divider()
                        .background(TM.bgTertiary)

                    // Stats for current point
                    if store.scrolledPointIndex < detail.trackPoints.count {
                        let point = detail.trackPoints[store.scrolledPointIndex]
                        currentPointStats(point: point)
                    }

                    // Add milestone button
                    addMilestoneButton

                    Spacer()
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
            ToolbarItem(placement: .primaryAction) {
                Button("Renommer", systemImage: "square.and.pencil") {
                    Haptic.light.trigger()
                    store.send(.renameButtonTapped)
                }
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .destructiveAction) {
                Button("Supprimer", systemImage: "trash", role: .destructive) {
                    Haptic.warning.trigger()
                    store.send(.deleteTrailButtonTapped)
                }
                .tint(Color.red)
            }
        }
        .toolbarRole(.editor)
        .alert($store.scope(state: \.alert, action: \.alert))
        .alert(
            "Renommer le parcours",
            isPresented: Binding(
                get: { store.isRenamingTrail },
                set: { if !$0 { store.send(.renameCancelled) } }
            )
        ) {
            TextField("Nom du parcours", text: $store.editedTrailName)
            Button("Annuler", role: .cancel) {
                Haptic.light.trigger()
                store.send(.renameCancelled)
            }
            Button("Renommer") {
                Haptic.medium.trigger()
                store.send(.renameConfirmed)
            }
            .keyboardShortcut(.defaultAction)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(
            item: $store.scope(state: \.milestoneSheet, action: \.milestoneSheet)
        ) { sheetStore in
            MilestoneSheetView(store: sheetStore)
                .presentationDetents([.large])
                .presentationBackground(TM.bgCard)
        }
    }

    // MARK: - Current Point Stats

    private func currentPointStats(point: TrackPoint) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("ALTITUDE")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(TM.textMuted)
                Text("\(Int(point.elevation)) m")
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.textPrimary)
            }

            VStack(spacing: 2) {
                Text("DISTANCE")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(TM.textMuted)
                Text(String(format: "%.2f km", point.distance / 1000))
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.textPrimary)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Add Milestone Button

    private var addMilestoneButton: some View {
        Button {
            Haptic.medium.trigger()
            store.send(.profileTapped(store.scrolledPointIndex))
        } label: {
            Label("Ajouter un repere", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TM.accent, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Milestone Sheet View

struct MilestoneSheetView: View {
    @Bindable var store: StoreOf<MilestoneSheetFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Type selector
                    sectionLabel("TYPE")

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
                        Haptic.success.trigger()
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark", role: .cancel) {
                        Haptic.light.trigger()
                        store.send(.dismissTapped)
                    }
                }
                ToolbarItem(placement: .title) {
                    Text(store.isEditing ? "Modifier" : "Nouveau repère")
                }
                ToolbarItem(placement: .subtitle) {
                    PointStatsView(distanceMeters: store.distance, altitudeMeters: store.elevation)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
            Haptic.selection.trigger()
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
        dPlus: 450
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
                                state.originalMilestones = ms
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

#Preview("Editor - With Milestones") {
    EditorPreviewWrapper(milestones: PreviewData.milestones(from: PreviewData.trackPoints))
}

#Preview("Editor - Empty Milestones") {
    EditorPreviewWrapper(milestones: [])
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
