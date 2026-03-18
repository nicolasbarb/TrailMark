import SwiftUI
import ComposableArchitecture

// @Observable so wrapper views can react, but EditorView body NEVER reads .index
@Observable
final class ScrollIndexHolder {
    var index: Int = 0
}

struct EditorView: View {
    @Bindable var store: StoreOf<EditorFeature>
    @State private var scrollTarget: ScrollTarget?
    @State private var profileStatsData: ProfileStatsData?
    @State private var scrollIndexHolder = ScrollIndexHolder()
    @State private var highlightedMilestoneId: Int64?

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            if let detail = store.trailDetail {
                VStack(spacing: 0) {
                    // Mini profile overview (isolated wrapper observes scrollIndexHolder)
                    MiniProfileWrapper(
                        trackPoints: detail.trackPoints,
                        milestones: store.milestones,
                        scrollIndexHolder: scrollIndexHolder,
                        onIndexSelected: { index in
                            scrollTarget = ScrollTarget(index: index, animated: false)
                        }
                    )

                    // Scrollable profile (main) with stats overlay
                    ZStack(alignment: .top) {
                        ScrollableElevationProfileView(
                            trackPoints: detail.trackPoints,
                            milestones: store.milestones,
                            editingMilestoneId: highlightedMilestoneId,
                            statsData: profileStatsData,
                            scrollTarget: $scrollTarget,
                            onScrollIndexChanged: { [scrollIndexHolder] index in
                                scrollIndexHolder.index = index
                            },
                            onMilestoneTapped: { milestone in
                                // 1. Scroll to milestone
                                scrollTarget = ScrollTarget(index: milestone.pointIndex, animated: true)

                                Task { @MainActor in
                                    // 2. After scroll, show highlight
                                    try? await Task.sleep(for: .milliseconds(350))
                                    highlightedMilestoneId = milestone.id

                                    // 3. After highlight, open sheet
                                    try? await Task.sleep(for: .milliseconds(300))
                                    Haptic.medium.trigger()
                                    store.send(.editMilestone(milestone))
                                }
                            }
                        )

                        // Overlays (isolated wrappers — only re-render on scroll)
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
//                    .containerRelativeFrame(.vertical) { height, _ in height * 0.5 }
                    
//                    Spacer()

                    // Milestone carousel (fills remaining space)
//                    ProfileStatsWrapper(
//                        scrollIndexHolder: scrollIndexHolder,
//                        statsData: profileStatsData,
//                        milestones: store.milestones,
//                        onGoToMilestone: { milestone in
//                            scrollTarget = ScrollTarget(index: milestone.pointIndex, animated: true)
//                        },
//                        onEditMilestone: { milestone in
//                            highlightedMilestoneId = milestone.id
//                            Haptic.medium.trigger()
//                            store.send(.editMilestone(milestone))
//                        },
//                        onScrolledToMilestone: { milestone in
//                            scrollTarget = ScrollTarget(index: milestone.pointIndex, animated: true)
//                        }
//                    )
//                    .padding(.bottom, 12)

                    // Add milestone button (glass, bottom)
//                    addMilestoneButton
//                        .padding(.horizontal, 16)
//                        .padding(.bottom, 16)
                    
                    SegmentInfoWrapper(
                        scrollIndexHolder: scrollIndexHolder,
                        statsData: profileStatsData,
                        milestones: store.milestones,
                        onGoToMilestone: { milestone in
                            scrollTarget = ScrollTarget(index: milestone.pointIndex, animated: true)
                        },
                        onEditMilestone: { milestone in
                            highlightedMilestoneId = milestone.id
                            Haptic.medium.trigger()
                            store.send(.editMilestone(milestone))
                        },
                        onAddMilestone: {
                            Haptic.medium.trigger()
                            store.send(.profileTapped(scrollIndexHolder.index))
                        }
                    )
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
//            ToolbarItem(placement: .primaryAction) {
//                Button("Renommer", systemImage: "square.and.pencil") {
//                    Haptic.light.trigger()
//                    store.send(.renameButtonTapped)
//                }
//            }
//            ToolbarItem(placement: .destructiveAction) {
//                Button("Supprimer", systemImage: "trash", role: .destructive) {
//                    Haptic.warning.trigger()
//                    store.send(.deleteTrailButtonTapped)
//                }
//                .tint(Color.red)
//            }
//            if store.isPremium {
                ToolbarItem(placement: .topBarTrailing) {

                    Text("PRO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(TM.accent, in: RoundedRectangle(cornerRadius: 4))
                }
//                .sharedBackgroundVisibility(.hidden)
//            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Renommer le fichier", systemImage: "square.and.pencil") {
                        Haptic.light.trigger()
                        store.send(.renameButtonTapped) }
                    Button("Supprimer le fichier", systemImage: "trash", role: .destructive) {
                        Haptic.warning.trigger()
                        store.send(.deleteTrailButtonTapped)
                    }
//                    Button("Signaler un bug", systemImage: "ladybug") {
//                        Haptic.light.trigger()
//                        store.send(.deleteTrailButtonTapped)
//                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                
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
        .onChange(of: store.trailDetail?.trackPoints.count) { _, newCount in
            if let count = newCount, count > 0,
               let detail = store.trailDetail {
                profileStatsData = ProfileStatsData(trackPoints: detail.trackPoints)
            }
        }
        .task(id: store.trailDetail?.trail.id) {
            // Compute stats data when detail becomes available
            if let detail = store.trailDetail {
                profileStatsData = ProfileStatsData(trackPoints: detail.trackPoints)
            }
        }
        .sheet(
            item: $store.scope(state: \.milestoneSheet, action: \.milestoneSheet)
        ) { sheetStore in
            MilestoneSheetView(store: sheetStore)
                .presentationDetents([.fraction(0.5), .large])
                .presentationBackground(TM.bgCard)
                .onDisappear {
                    highlightedMilestoneId = nil
                }
        }
        .fullScreenCover(
            item: $store.scope(state: \.paywall, action: \.paywall)
        ) { paywallStore in
            PaywallContainerView(store: paywallStore)
        }
    }


    // MARK: - Add Milestone Button (Primary CTA)

    private var isOnExistingMilestone: Bool {
        store.milestones.contains { abs($0.pointIndex - scrollIndexHolder.index) <= 5 }
    }

    private var addMilestoneButton: some View {
        Button {
            Haptic.medium.trigger()
            store.send(.profileTapped(scrollIndexHolder.index))
        } label: {
            Text("Ajouter un repère")
                .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                Capsule()
                    .fill(TM.accent)
                    .shadow(color: TM.accent.opacity(0.4), radius: 12, x: 0, y: 6)
            }
        }
        .disabled(isOnExistingMilestone)
        .opacity(isOnExistingMilestone ? 0.4 : 1)
    }
}

// MARK: - Milestone Sheet View

struct MilestoneSheetView: View {
    @Bindable var store: StoreOf<MilestoneSheetFeature>
    @Namespace private var typeIndicator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Type selector (horizontal cards from Approach 3)
                    sectionLabel("TYPE")

                    typeCardsSelector(selectedType: store.selectedType)
                        .padding(.top, 8)

                    // MARK: - Message Section (conditional layout)
                    if let autoMessage = store.autoMessage {
                        // montee/descente: auto block + personal complement
                        HStack(spacing: 6) {
                            sectionLabel("ANNONCE VOCALE")
                            proBadge
                        }
                        .padding(.top, 14)

                        // Auto-generated text block (read-only)
                        Text(autoMessage)
                            .font(.body)
                            .foregroundStyle(TM.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
                            .opacity(store.isPremium ? 1 : 0.7)
                            .padding(.top, 8)

                        sectionLabel("COMPLEMENT PERSO")
                            .padding(.top, 14)

                        TextField(
                            "Ajouter un message personnel\u{2026}",
                            text: $store.personalMessage,
                            axis: .vertical
                        )
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
                    } else {
                        // Non montee/descente: plain message field
                        sectionLabel("MESSAGE TTS")
                            .padding(.top, 14)

                        TextField(
                            messagePlaceholder,
                            text: $store.personalMessage,
                            axis: .vertical
                        )
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
                    }

                    // Full-width listen button
                    listenButton
                        .padding(.top, 12)

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

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(store.isEditing ? "Modifier" : "Nouveau repère")
                            .font(.headline)
                        PointStatsView(distanceMeters: store.distance, altitudeMeters: store.elevation)
                    }
                }

                if store.isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Supprimer", systemImage: "trash", role: .destructive) {
                            Haptic.warning.trigger()
                            store.send(.deleteButtonTapped)
                        }
                        .tint(TM.danger)
                    }

                    ToolbarSpacer(.fixed, placement: .confirmationAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider", systemImage: "checkmark") {
                        Haptic.success.trigger()
                        store.send(.saveButtonTapped)
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(TM.textMuted)
    }

    // MARK: - PRO Badge

    private var proBadge: some View {
        HStack(spacing: 4) {
            if !store.isPremium {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.black)
            }
            Text("PRO")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(TM.accent, in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Listen Button

    private var isListenDisabled: Bool {
        (store.autoMessage ?? "").isEmpty && store.personalMessage.isEmpty
    }

    private var listenButton: some View {
        Button {
            Haptic.light.trigger()
            if store.isPlayingPreview {
                store.send(.stopTTSTapped)
            } else {
                store.send(.previewTTSTapped)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.isPlayingPreview ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(store.isPlayingPreview ? "Arrêter" : "Écouter l'annonce")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isListenDisabled ? TM.textMuted : TM.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isListenDisabled ? TM.border : TM.accent, lineWidth: 1)
            )
        }
        .disabled(isListenDisabled)
        .accessibilityLabel(store.isPlayingPreview ? "Arrêter la lecture" : "Écouter l'annonce")
    }

    // MARK: - Message Placeholder

    private var messagePlaceholder: String {
        switch store.selectedType {
        case .ravito: "ex: Ravitaillement, prenez à gauche\u{2026}"
        case .danger: "ex: Attention, passage technique\u{2026}"
        case .info: "ex: Belle vue sur la vallée\u{2026}"
        case .plat: "ex: Portion plate, relancez\u{2026}"
        case .montee, .descente: "Ajouter un message personnel\u{2026}"
        }
    }

    // MARK: - Type Selector

    private func typeCardsSelector(selectedType: MilestoneType) -> some View {
        HStack(spacing: 0) {
            ForEach(MilestoneType.allCases, id: \.self) { (type: MilestoneType) in
                let isSelected = selectedType == type

                Button {
                    Haptic.selection.trigger()
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        store.send(.typeSelected(type))
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? type.color : TM.textMuted)
                            .frame(width: 20, height: 20)

                        Text(type.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? TM.textPrimary : TM.textMuted)
                            .frame(height: 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(type.color.opacity(0.12))
                                .matchedGeometryEffect(id: "typeBackground", in: typeIndicator)
                        }
                    }
                }
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
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

// MARK: - Isolated Wrapper Views (observe ScrollIndexHolder, NOT EditorView)

/// Only this view re-renders when scrollIndexHolder.index changes.
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

/// Only this view re-renders when scrollIndexHolder.index changes.
/// EditorView body is NOT re-evaluated.
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

/// Only this view re-renders when scrollIndexHolder.index changes.
private struct SegmentInfoWrapper: View {
    let scrollIndexHolder: ScrollIndexHolder
    let statsData: ProfileStatsData?
    let milestones: [Milestone]
    var onGoToMilestone: ((Milestone) -> Void)?
    var onEditMilestone: ((Milestone) -> Void)?
    var onAddMilestone: (() -> Void)?

    private var currentSegment: ProfileStatsData.SegmentData? {
        guard let stats = statsData else { return nil }
        let idx = scrollIndexHolder.index
        guard idx < stats.segmentIndices.count else { return nil }
        let segmentIdx = stats.segmentIndices[idx]
        guard segmentIdx < stats.segments.count else { return nil }
        return stats.segments[segmentIdx]
    }

    @State private var showMilestonesList = false

    private var segmentMilestones: [Milestone] {
        guard let segment = currentSegment else { return [] }
        return milestones.filter { $0.pointIndex >= segment.startIndex && $0.pointIndex <= segment.endIndex }
    }

    var body: some View {
        if let segment = currentSegment {
            VStack(alignment: .leading, spacing: 10) {
                // Titre + repères count + actions
                HStack(alignment: .center) {
                    Text("Segment")
                        .font(.headline)
                        .foregroundStyle(TM.textPrimary)

                    Spacer()

                    HStack(spacing: 8) {
                        if !segmentMilestones.isEmpty {
                            Button {
                                showMilestonesList = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("\(segmentMilestones.count)")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(segment.type.color)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 11, weight: .bold))
                                Text("0")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(TM.textTertiary)
                        }

                        Button {
                            onAddMilestone?()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(TM.accent)
                        }
                    }
                }

                Divider()

                // Type / distance / dénivelé
                HStack(spacing: 0) {
                    // Type
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type")
                            .font(.caption)
                            .foregroundStyle(TM.textTertiary)
                        HStack(spacing: 4) {
                            Image(systemName: segment.type.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(segment.type.color)
                            Text(segment.type.label)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(TM.textPrimary)
                        }
                    }

                    Divider()
                        .padding(.horizontal, 12)

                    // Distance
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundStyle(TM.textTertiary)
                        Text(formatDistance(segment.distance))
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .foregroundStyle(TM.textPrimary)
                    }

                    Divider()
                        .padding(.horizontal, 12)

                    // Dénivelé
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dénivelé")
                            .font(.caption)
                            .foregroundStyle(TM.textTertiary)
                        Text("\(segment.type == .descente ? "-" : "+")\(segment.elevationChange) m")
                            .font(.system(.body, design: .monospaced, weight: .semibold))
                            .foregroundStyle(TM.textPrimary)
                    }
                }
                .frame(maxHeight: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .fixedSize(horizontal: false, vertical: true)
            .sheet(isPresented: $showMilestonesList) {
                NavigationStack {
                    List(segmentMilestones) { milestone in
                        Button {
                            showMilestonesList = false
                            onGoToMilestone?(milestone)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: milestone.milestoneType.systemImage)
                                    .foregroundStyle(milestone.milestoneType.color)
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
                        }
                    }
                    .navigationTitle("Repères du segment")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(role: .close) {
                                showMilestonesList = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
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

/// Only this view re-renders when scrollIndexHolder.index changes.
private struct ProfileStatsWrapper: View {
    let scrollIndexHolder: ScrollIndexHolder
    let statsData: ProfileStatsData?
    let milestones: [Milestone]
    var onGoToMilestone: ((Milestone) -> Void)?
    var onEditMilestone: ((Milestone) -> Void)?
    var onScrolledToMilestone: ((Milestone) -> Void)?

    var body: some View {
        if let stats = statsData,
           scrollIndexHolder.index < stats.trackPoints.count {
            ProfileStatsView(
                statsData: stats,
                currentIndex: scrollIndexHolder.index,
                milestones: milestones,
                onGoToMilestone: onGoToMilestone,
                onEditMilestone: onEditMilestone,
                onScrolledToMilestone: onScrolledToMilestone
            )
        }
    }
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
                personalMessage: "",
                name: "",
                autoMessage: "Montée. 1 virgule 8 kilomètres à 12 pourcent. 215 mètres de dénivelé positif."
            )
        ) {
            MilestoneSheetFeature()
        }
    )
    .presentationBackground(TM.bgCard)
}
