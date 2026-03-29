import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct ImportView: View {
    @Bindable var store: StoreOf<ImportStore>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationToken = UUID()

    /// Single source of truth for the import animation sequence
    private enum ImportPhase: Equatable {
        case upload              // Pills scrolling, CTA visible
        case importing           // CTA shows spinner
        case exitingPills        // Pills accelerate out, rest stays
        case exitingContent      // Title/button fade, subtitle transforms
        case drawingProfile      // Profile draws left to right
        case showingSegments     // Colored segments fade in
        case revealingMilestones // Milestones pop one by one
        case complete            // Header, buttons, explanation visible
    }

    @State private var phase: ImportPhase
    @State private var visibleMilestoneCount: Int
    @State private var milestoneAnimationStartDate: Date?
    @State private var coloredProfileVisible: Bool
    private let totalMilestoneDuration: Double = 1.5

    init(store: StoreOf<ImportStore>) {
        self.store = store

        switch store.phase {
        case .upload:
            _phase = State(initialValue: .upload)
            _coloredProfileVisible = State(initialValue: false)
            _visibleMilestoneCount = State(initialValue: 0)
        case .analyzing:
            _phase = State(initialValue: .importing)
            _coloredProfileVisible = State(initialValue: false)
            _visibleMilestoneCount = State(initialValue: 0)
        case .animatingProfile:
            _phase = State(initialValue: .drawingProfile)
            _coloredProfileVisible = State(initialValue: false)
            _visibleMilestoneCount = State(initialValue: 0)
        case .result:
            _phase = State(initialValue: .complete)
            _coloredProfileVisible = State(initialValue: true)
            _visibleMilestoneCount = State(initialValue: store.detectedMilestones.count)
        }
    }

    // MARK: - Derived properties

    private var pillsExiting: Bool {
        switch phase {
        case .exitingPills, .exitingContent: true
        default: false
        }
    }

    private var showProfileView: Bool {
        switch phase {
        case .drawingProfile, .showingSegments, .revealingMilestones, .complete: true
        default: false
        }
    }

    private var uploadContentFading: Bool {
        phase == .exitingContent
    }

    private var showSegments: Bool {
        switch phase {
        case .showingSegments, .revealingMilestones, .complete: true
        default: false
        }
    }

    private var showMilestones: Bool {
        phase == .revealingMilestones || phase == .complete
    }

    private var showContent: Bool {
        phase == .complete
    }

    private var hasMilestones: Bool {
        !store.detectedMilestones.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [TM.accent.opacity(0.08), TM.bgSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if showProfileView {
                    profileResultView
                } else {
                    uploadPhaseView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showProfileView || phase == .complete {
                        Button("common.close", systemImage: "xmark", role: .cancel) {
                            Haptic.light.trigger()
                            store.send(.dismissTapped)
                        }
                    }
                }
            }
            .toolbar(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(store.phase == .analyzing)
        .fileImporter(
            isPresented: Binding(
                get: { store.isShowingFilePicker },
                set: { newValue in
                    if !newValue {
                        store.send(.filePickerDismissed)
                    }
                }
            ),
            allowedContentTypes: gpxContentTypes,
            onCompletion: { result in
                switch result {
                case .success(let url):
                    store.send(.fileSelected(url.path))
                case .failure:
                    store.send(.filePickerDismissed)
                }
            }
        )
        .fullScreenCover(
            item: $store.scope(state: \.paywall, action: \.paywall)
        ) { paywallStore in
            PaywallContainerView(store: paywallStore)
        }
        .onAppear {
            // Sync view phase with store phase for previews
            syncPhaseWithStore()
        }
        .onChange(of: store.phase) { _, newPhase in
            switch newPhase {
            case .analyzing:
                phase = .importing
            case .animatingProfile:
                startUploadExitAnimation()
            case .result:
                startResultTransition()
            case .upload:
                // Reset on error
                phase = .upload
                visibleMilestoneCount = 0
                milestoneAnimationStartDate = nil
                coloredProfileVisible = false
            }
        }
    }

    // MARK: - Upload Phase

    private var uploadPhaseView: some View {
        VStack(spacing: 0) {
            // Pills en haut
            trailPillsView
                .padding(.top, 16)

            // Texte centré — fixed height prevents reflow
            VStack(spacing: 8) {
                Text("import.upload.title")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TM.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(uploadContentFading ? 0 : 1)

                Text("import.upload.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(TM.textMuted)
                    .multilineTextAlignment(.center)
                    .opacity(uploadContentFading ? 0 : 1)

                // Error message
                if let error = store.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TM.danger)
                        .padding(.top, 4)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 28)
            .padding(.horizontal, 28)

            Spacer()

            // CTA en bas — disparaît en fondu
            Button {
                Haptic.medium.trigger()
                store.send(.uploadZoneTapped)
            } label: {
                Text("import.upload.cta")
                    .opacity(phase == .importing ? 0 : 1)
                    .overlay {
                        if phase == .importing {
                            ProgressView()
                                .controlSize(.regular)
                        }
                    }
            }
            .primaryButton(size: .large, width: .flexible, shape: .capsule)
            .disabled(phase == .importing)
            .padding(.horizontal, 24)
            .opacity(uploadContentFading ? 0 : 1)

            Spacer()
                .frame(height: 24)
                .opacity(uploadContentFading ? 0 : 1)

        }
        .animation(reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.1), value: uploadContentFading)
    }

    // MARK: - Upload Exit Animation

    private func startUploadExitAnimation() {
        if reduceMotion {
            phase = .drawingProfile
            return
        }
        // Step 1: pills accelerate out (TimelineView-driven, not SwiftUI-animated)
        phase = .exitingPills

        // Wait for pills to mostly exit, then chain SwiftUI animations for steps 2-3
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            guard phase == .exitingPills else { return }

            // Step 2: title/button fade out
            withAnimation(.smooth(duration: 0.3)) {
                phase = .exitingContent
            } completion: {
                // Step 3: show profile immediately (upload already invisible)
                animationToken = UUID() // Reset so drawing starts from 0
                phase = .drawingProfile
            }
        }
    }

    /// Syncs view-local phase with store phase on appear (for previews)
    private func syncPhaseWithStore() {
        switch store.phase {
        case .upload:
            break // already .upload
        case .analyzing:
            phase = .importing
        case .animatingProfile:
            phase = .drawingProfile
        case .result:
            // Skip animations, show final state directly
            coloredProfileVisible = true
            visibleMilestoneCount = store.detectedMilestones.count
            milestoneAnimationStartDate = nil
            phase = .complete
        }
    }

    // MARK: - Trail Pills

    private static let trailNames: [[String]] = [
        ["UTMB", "Tour du Mont Blanc", "Diagonale des Fous", "CCC", "Echappee Belle"],
        ["Western States", "Tor des Geants", "SainteLyon", "Templiers", "Pikes Peak"],
        ["Lavaredo", "Transgrancanaria", "Hardrock 100", "Eiger Ultra Trail", "GR20"],
        ["Cape Town Ultra", "Trail du Ventoux", "Oman by UTMB", "Patagonia Run", "MiUT"],
    ]

    private static let pillConfigs: [(reversed: Bool, duration: Double, startOffset: CGFloat)] = [
        (false, 25, 0),
        (true, 32, -60),
        (false, 28, -120),
        (true, 26, -40),
    ]

    private var trailPillsView: some View {
        VStack(spacing: 8) {
            ForEach(Array(Self.trailNames.enumerated()), id: \.offset) { index, row in
                let config = Self.pillConfigs[index]
                ScrollingPillRow(
                    names: row,
                    reversed: config.reversed,
                    duration: config.duration,
                    startOffset: config.startOffset,
                    exiting: pillsExiting
                )
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.1),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Unified Profile + Result View

    private var profileResultView: some View {
        VStack(spacing: 0) {
            // Header — fades in during .complete
            resultHeader
                .padding(.top, 24)
                .padding(.horizontal, 20)
                .opacity(showContent ? 1 : 0)

            // Profile — just below header
            ZStack(alignment: .topTrailing) {
                // Layer 1: Drawing animation (accent color, stays visible under colored)
                RealProfileDrawingAnimation(
                    trackPoints: store.parsedTrackPoints,
                    onFinished: {
                        store.send(.profileAnimationFinished)
                    },
                    restartToken: animationToken
                )
                .frame(height: 150)

                // Layer 2: Colored profile fades in ON TOP of accent profile
                ElevationProfilePreview(
                    trackPoints: store.parsedTrackPoints,
                    milestones: [],
                    showMilestones: false
                )
                .frame(height: 150)
                .opacity(coloredProfileVisible ? 1 : 0)
                .animation(.smooth(duration: 1.2), value: coloredProfileVisible)

                // Layer 3: SwiftUI milestone markers (animated individually)
                if showMilestones {
                    MilestoneMarkersOverlay(
                        trackPoints: store.parsedTrackPoints,
                        milestones: store.detectedMilestones,
                        visibleCount: visibleMilestoneCount
                    )
                    .frame(height: 150)
                }

                if !store.isPremium && hasMilestones {
                    ProBadge()
                        .padding(8)
                        .opacity(showContent ? 1 : 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Phase text — changes at each step
            Group {
                switch phase {
                case .drawingProfile:
                    Text("import.phase.creatingProfile")
                case .showingSegments, .revealingMilestones:
                    Text("import.phase.detectingMilestones")
                case .complete:
                    if hasMilestones {
                        Text("import.result.explanation")
                    } else {
                        Color.clear.frame(height: 0)
                    }
                default:
                    Text("import.phase.creatingProfile")
                }
            }
            .font(.headline)
            .foregroundStyle(TM.textPrimary)
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .animation(reduceMotion ? .none : .spring(duration: 0.3, bounce: 0.1), value: phase)

            Spacer()

            // Action buttons — fades in during .complete
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

        }
        // TimelineView-driven milestone counter (frame-synced)
        .overlay {
            if phase == .revealingMilestones, let startDate = milestoneAnimationStartDate {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startDate)
                    let progress = min(elapsed / totalMilestoneDuration, 1.0)
                    let eased = 0.5 * (1 - cos(Double.pi * progress))
                    let targetCount = Int(eased * Double(store.detectedMilestones.count))

                    Color.clear
                        .onChange(of: targetCount) { oldCount, newCount in
                            if newCount > visibleMilestoneCount {
                                visibleMilestoneCount = newCount
                                Haptic.light.trigger()
                            }
                        }
                        .onChange(of: progress >= 1.0) { _, finished in
                            if finished {
                                visibleMilestoneCount = store.detectedMilestones.count
                                milestoneAnimationStartDate = nil
                                withAnimation(.spring(duration: 0.5, bounce: 0.1)) {
                                    phase = .complete
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Result Transition

    private func startResultTransition() {
        let milestoneCount = store.detectedMilestones.count

        if reduceMotion {
            coloredProfileVisible = true
            visibleMilestoneCount = milestoneCount
            phase = .complete
            return
        }

        // Phase 1: colored profile fades in over accent profile
        phase = .showingSegments
        withAnimation(.smooth(duration: 1.2)) {
            coloredProfileVisible = true
        } completion: {
            if milestoneCount > 0 {
                // Phase 2: milestones appear one by one
                phase = .revealingMilestones
                milestoneAnimationStartDate = Date()
            } else {
                // No milestones — skip to complete
                withAnimation(.spring(duration: 0.5, bounce: 0.1)) {
                    phase = .complete
                }
            }
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(TM.accent)

            VStack(alignment: .leading, spacing: 4) {
                if hasMilestones {
                    Text("import.result.foundMilestones \(store.detectedMilestones.count)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(TM.textPrimary)
                } else {
                    Text("import.result.imported")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(TM.textPrimary)
                }

                if let trail = store.parsedTrail {
                    Text(trail.name)
                        .font(.subheadline)
                        .foregroundStyle(TM.textMuted)

                    HStack(spacing: 12) {
                        Text(String(format: "%.1f km", trail.distance / 1000))
                        Text("D+ \(trail.dPlus)m")
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TM.textMuted)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if !hasMilestones {
            Button {
                Haptic.medium.trigger()
                store.send(.skipTapped)
            } label: {
                Text("common.continue")
            }
            .primaryButton(size: .large, width: .flexible, shape: .capsule)
        } else if store.isPremium {
            VStack(spacing: 12) {
                Button {
                    Haptic.medium.trigger()
                    store.send(.continueWithMilestonesTapped)
                } label: {
                    Text("common.continue")
                }
                .primaryButton(size: .large, width: .flexible, shape: .capsule)

                Button {
                    Haptic.light.trigger()
                    store.send(.skipTapped)
                } label: {
                    Text("import.result.skipButton")
                        .underline()
                }
                .tertiaryButton(size: .small, tint: .secondary)
            }
        } else {
            VStack(spacing: 12) {
                Button {
                    Haptic.medium.trigger()
                    store.send(.unlockTapped)
                } label: {
                    Label {
                        Text("import.result.unlockDetection")
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                }
                .primaryButton(size: .large, width: .flexible, shape: .capsule)

                Button {
                    Haptic.light.trigger()
                    store.send(.skipTapped)
                } label: {
                    Text("import.result.manualButton")
                        .underline()
                }
                .tertiaryButton(size: .small, tint: .secondary)
            }
        }
    }

    // MARK: - Content Types

    private var gpxContentTypes: [UTType] {
        var types: [UTType] = [.xml]
        if let gpxType = UTType(filenameExtension: "gpx") {
            types.insert(gpxType, at: 0)
        }
        return types
    }
}

// MARK: - Preview Helpers

@MainActor
private func loadPreviewGPX() -> (Trail, [TrackPoint], [Milestone]) {
    guard let url = Bundle.main.url(forResource: "utmb-preview", withExtension: "gpx") else {
        return (Trail(id: nil, name: "Preview", distance: 0, dPlus: 0), [], [])
    }
    do {
        let (parsedPoints, dPlus) = try GPXParser.parse(url: url)
        let trail = Trail(
            id: nil,
            name: GPXParser.trailName(from: url),
            distance: parsedPoints.last?.distance ?? 0,
            dPlus: dPlus
        )
        let trackPoints = parsedPoints.enumerated().map { index, point in
            TrackPoint(
                id: nil, trailId: 0, index: index,
                latitude: point.latitude, longitude: point.longitude,
                elevation: point.elevation, distance: point.distance
            )
        }
        let milestones = MilestoneDetector.detect(from: trackPoints, trailId: 0)
        return (trail, trackPoints, milestones)
    } catch {
        return (Trail(id: nil, name: "Preview", distance: 0, dPlus: 0), [], [])
    }
}

#Preview("Upload") {
    ImportView(
        store: Store(initialState: ImportStore.State()) {
            ImportStore()
        }
    )
}

#Preview("Upload - Loading") {
    ImportView(
        store: Store(
            initialState: ImportStore.State(phase: .analyzing)
        ) {
            ImportStore()
        }
    )
}

#Preview("Animation → Result") {
    let (trail, trackPoints, milestones) = loadPreviewGPX()
    ImportView(
        store: Store(
            initialState: {
                var state = ImportStore.State(
                    phase: .animatingProfile,
                    parsedTrail: trail,
                    parsedTrackPoints: trackPoints,
                    detectedMilestones: milestones
                )
                state.detectionFinished = true
                return state
            }()
        ) {
            ImportStore()
        }
    )
}

#Preview("Result - Free") {
    let (trail, trackPoints, milestones) = loadPreviewGPX()
    ImportView(
        store: Store(
            initialState: {
                var state = ImportStore.State(
                    phase: .result,
                    parsedTrail: trail,
                    parsedTrackPoints: trackPoints,
                    detectedMilestones: milestones
                )
                state.profileAnimationFinished = true
                state.detectionFinished = true
                return state
            }()
        ) {
            ImportStore()
        }
    )
}

#Preview("Result - Premium") {
    let (trail, trackPoints, milestones) = loadPreviewGPX()
    ImportView(
        store: Store(
            initialState: {
                var state = ImportStore.State(
                    phase: .result,
                    parsedTrail: trail,
                    parsedTrackPoints: trackPoints,
                    detectedMilestones: milestones,
                    isPremium: true
                )
                state.profileAnimationFinished = true
                state.detectionFinished = true
                return state
            }()
        ) {
            ImportStore()
        }
    )
}
