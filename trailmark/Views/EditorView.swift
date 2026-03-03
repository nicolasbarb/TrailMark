import SwiftUI
import ComposableArchitecture

struct EditorView: View {
    @Bindable var store: StoreOf<EditorFeature>
    @State private var scrollToIndex: Int?

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            if let detail = store.trailDetail {
                VStack(spacing: 0) {
                    // Mini profile overview
                    MiniProfileView(
                        trackPoints: detail.trackPoints,
                        milestones: store.milestones,
                        currentIndex: store.scrolledPointIndex,
                        onIndexSelected: { index in
                            scrollToIndex = index
                        }
                    )

                    Rectangle()
                        .fill(TM.bgTertiary)
                        .frame(height: 1)

                    // Scrollable profile (main)
                    ScrollableElevationProfileView(
                        trackPoints: detail.trackPoints,
                        milestones: store.milestones,
                        scrolledPointIndex: Binding(
                            get: { store.scrolledPointIndex },
                            set: { store.send(.scrollPositionChanged($0)) }
                        ),
                        scrollToIndex: $scrollToIndex
                    )
                    .containerRelativeFrame(.vertical) { height, _ in height * 0.4 }

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
            Label("Ajouter un repère", systemImage: "plus.circle.fill")
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

@MainActor
private enum PreviewData {
    /// Charge les points depuis le GPX bundlé (preview-trail.gpx)
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
            print("Preview GPX load failed: \(error)")
            return []
        }
    }

    static var trail: Trail {
        let points = trackPoints
        let distance = points.last?.distance ?? 0
        let dPlus = calculateDPlus(points: points)
        return Trail(
            id: 1,
            name: "Thou Verdun",
            createdAt: Date(),
            distance: distance,
            dPlus: dPlus
        )
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
            Milestone(
                id: 1,
                trailId: 1,
                pointIndex: 200,
                latitude: points[200].latitude,
                longitude: points[200].longitude,
                elevation: points[200].elevation,
                distance: points[200].distance,
                type: .montee,
                message: "Début de la montée vers le Mont Thou",
                name: "Montée Thou"
            ),
            Milestone(
                id: 2,
                trailId: 1,
                pointIndex: 500,
                latitude: points[500].latitude,
                longitude: points[500].longitude,
                elevation: points[500].elevation,
                distance: points[500].distance,
                type: .info,
                message: "Sommet du Mont Thou, belle vue !",
                name: "Mont Thou"
            ),
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
