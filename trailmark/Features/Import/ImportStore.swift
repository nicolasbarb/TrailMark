import Foundation
import ComposableArchitecture
import UniformTypeIdentifiers

@Reducer
struct ImportStore {
    @ObservableState
    struct State: Equatable, Sendable {
        var phase: Phase = .upload
        var isShowingFilePicker = false
        var error: String?

        // Données parsées (pas en DB, juste en mémoire)
        var parsedTrail: Trail?
        var parsedTrackPoints: [TrackPoint] = []
        var detectedMilestones: [Milestone] = []
        @Shared(.inMemory("isPremium")) var isPremium = false

        // Paywall
        @Presents var paywall: PaywallStore.State?

        var profileAnimationFinished = false
        var detectionFinished = false

        enum Phase: Equatable, Sendable {
            case upload
            case analyzing      // Parsing GPX
            case animatingProfile // Profile drawing with real data
            case result
        }
    }

    enum Action: Equatable {
        // Upload phase
        case uploadZoneTapped
        case filePickerDismissed
        case fileSelected(String) // URL path as String for Sendable

        // Analysis
        case parsingCompleted(Trail, [TrackPoint])
        case detectionCompleted([Milestone])
        case profileAnimationFinished
        case importFailed(String)

        // Result phase
        case unlockTapped
        case continueWithMilestonesTapped
        case skipTapped
        case dismissTapped

        // Output to parent - envoie les données en mémoire, pas de trailId
        case importCompleted(PendingTrailData)

        // Paywall
        case paywall(PresentationAction<PaywallStore.Action>)
    }

    private enum CancelID { case importing }

    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        ImportAnalyticsReducer()

        Reduce { state, action in
            switch action {
            // MARK: - Upload Phase

            case .uploadZoneTapped:
                state.isShowingFilePicker = true
                state.error = nil
                return .none

            case .filePickerDismissed:
                state.isShowingFilePicker = false
                return .none

            case let .fileSelected(urlPath):
                state.phase = .analyzing
                state.error = nil
                state.profileAnimationFinished = false
                state.detectionFinished = false
                let url = URL(fileURLWithPath: urlPath)

                return .run { send in
                    do {
                        let startTime = Date()

                        // 1. Parser le GPX
                        let (parsedPoints, dPlus) = try await MainActor.run {
                            try GPXParser.parse(url: url)
                        }
                        let trailName = GPXParser.trailName(from: url)
                        let totalDistance = parsedPoints.last?.distance ?? 0

                        // 2. Créer le trail (sans id, pas en DB)
                        let trail = Trail(
                            id: nil,
                            name: trailName,
                            createdAt: Date(),
                            distance: totalDistance,
                            dPlus: dPlus
                        )

                        // 3. Créer les track points
                        let trackPoints = parsedPoints.enumerated().map { index, point in
                            TrackPoint(
                                id: nil,
                                trailId: 0,
                                index: index,
                                latitude: point.latitude,
                                longitude: point.longitude,
                                elevation: point.elevation,
                                distance: point.distance
                            )
                        }

                        // 4. Minimum loading time (1s) to avoid spinner flash
                        let elapsed = Date().timeIntervalSince(startTime)
                        let remaining = max(0, 1.0 - elapsed)
                        if remaining > 0 {
                            try await Task.sleep(for: .seconds(remaining))
                        }

                        // 5. Send parsed data to start animation
                        await send(.parsingCompleted(trail, trackPoints))

                        // 6. Detect milestones in parallel with animation
                        let detectedMilestones = MilestoneDetector.detect(
                            from: trackPoints,
                            trailId: 0
                        )

                        await send(.detectionCompleted(detectedMilestones))
                    } catch let error as GPXParser.ParseError {
                        await send(.importFailed(error.localizedDescription))
                    } catch {
                        await send(.importFailed("Erreur lors de l'import: \(error.localizedDescription)"))
                    }
                }
                .cancellable(id: CancelID.importing, cancelInFlight: true)

            // MARK: - Analysis Result

            case let .parsingCompleted(trail, trackPoints):
                state.parsedTrail = trail
                state.parsedTrackPoints = trackPoints
                state.phase = .animatingProfile
                return .none

            case let .detectionCompleted(milestones):
                state.detectedMilestones = milestones
                state.detectionFinished = true
                // If animation already finished, go to result
                if state.profileAnimationFinished {
                    state.phase = .result
                }
                return .none

            case .profileAnimationFinished:
                state.profileAnimationFinished = true
                // If detection already finished, go to result
                if state.detectionFinished {
                    state.phase = .result
                }
                return .none

            case let .importFailed(message):
                state.phase = .upload
                state.error = message
                return .none

            // MARK: - Result Phase Actions

            case .unlockTapped:
                state.paywall = PaywallStore.State()
                return .none

            case .continueWithMilestonesTapped:
                // Premium: continuer avec les jalons détectés
                guard let trail = state.parsedTrail else { return .none }
                let pendingData = PendingTrailData(
                    trail: trail,
                    trackPoints: state.parsedTrackPoints,
                    detectedMilestones: state.detectedMilestones
                )
                return .send(.importCompleted(pendingData))

            case .skipTapped:
                // Continuer sans les jalons détectés
                guard let trail = state.parsedTrail else { return .none }
                let pendingData = PendingTrailData(
                    trail: trail,
                    trackPoints: state.parsedTrackPoints,
                    detectedMilestones: [] // Pas de jalons
                )
                return .send(.importCompleted(pendingData))

            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }

            case .importCompleted:
                // Handled by parent
                return .none

            // MARK: - Paywall

            case .paywall(.presented(.purchaseCompleted)),
                 .paywall(.presented(.restoreCompleted)):
                // RevenueCat handles the purchase — isPremium updated via premiumStatusStream
                state.$isPremium.withLock { $0 = true }
                return .none

            case .paywall(.dismiss):
                state.paywall = nil
                return .none

            case .paywall:
                return .none
            }
        }
        .ifLet(\.$paywall, action: \.paywall) {
            PaywallStore()
        }
    }
}
