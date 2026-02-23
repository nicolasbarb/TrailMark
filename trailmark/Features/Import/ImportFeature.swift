import Foundation
import ComposableArchitecture
import UniformTypeIdentifiers

@Reducer
struct ImportFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var phase: Phase = .upload
        var isShowingFilePicker = false
        var error: String?

        // Données parsées (pas en DB, juste en mémoire)
        var parsedTrail: Trail?
        var parsedTrackPoints: [TrackPoint] = []
        var detectedMilestones: [Milestone] = []
        var isPremium = false

        // Paywall
        @Presents var paywall: PaywallFeature.State?

        enum Phase: Equatable, Sendable {
            case upload
            case analyzing
            case result
        }
    }

    enum Action: Equatable {
        // Upload phase
        case uploadZoneTapped
        case filePickerDismissed
        case fileSelected(String) // URL path as String for Sendable

        // Analysis
        case analysisCompleted(Trail, [TrackPoint], [Milestone])
        case importFailed(String)

        // Result phase
        case unlockTapped
        case continueWithMilestonesTapped
        case skipTapped
        case dismissTapped

        // Output to parent - envoie les données en mémoire, pas de trailId
        case importCompleted(PendingTrailData)

        // Premium status
        case premiumStatusLoaded(Bool)

        // Paywall
        case paywall(PresentationAction<PaywallFeature.Action>)
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.subscription) var subscription

    var body: some Reducer<State, Action> {
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
                let url = URL(fileURLWithPath: urlPath)

                return .merge(
                    // Charger le statut premium
                    .run { send in
                        let isPremium = await subscription.isPremium()
                        await send(.premiumStatusLoaded(isPremium))
                    },
                    // Parser et analyser (PAS de sauvegarde DB)
                    .run { send in
                        do {
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

                            // 3. Créer les track points (trailId sera assigné plus tard)
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

                            // 4. Détecter les jalons (en mémoire)
                            let detectedMilestones = MilestoneDetector.detect(
                                from: trackPoints,
                                trailId: 0
                            )

                            await send(.analysisCompleted(trail, trackPoints, detectedMilestones))
                        } catch let error as GPXParser.ParseError {
                            await send(.importFailed(error.localizedDescription))
                        } catch {
                            await send(.importFailed("Erreur lors de l'import: \(error.localizedDescription)"))
                        }
                    }
                )

            case let .premiumStatusLoaded(isPremium):
                state.isPremium = isPremium
                return .none

            // MARK: - Analysis Result

            case let .analysisCompleted(trail, trackPoints, milestones):
                state.phase = .result
                state.parsedTrail = trail
                state.parsedTrackPoints = trackPoints
                state.detectedMilestones = milestones
                return .none

            case let .importFailed(message):
                state.phase = .upload
                state.error = message
                return .none

            // MARK: - Result Phase Actions

            case .unlockTapped:
                // TODO: Remettre le paywall après les tests
                // state.paywall = PaywallFeature.State()
                // return .none

                // TEMP: Skip paywall pour tester
                guard let trail = state.parsedTrail else { return .none }
                let pendingData = PendingTrailData(
                    trail: trail,
                    trackPoints: state.parsedTrackPoints,
                    detectedMilestones: state.detectedMilestones
                )
                return .send(.importCompleted(pendingData))

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
                // Achat réussi: continuer avec les jalons détectés
                state.paywall = nil
                state.isPremium = true

                guard let trail = state.parsedTrail else { return .none }
                let pendingData = PendingTrailData(
                    trail: trail,
                    trackPoints: state.parsedTrackPoints,
                    detectedMilestones: state.detectedMilestones
                )
                return .send(.importCompleted(pendingData))

            case .paywall(.dismiss):
                state.paywall = nil
                return .none

            case .paywall:
                return .none
            }
        }
        .ifLet(\.$paywall, action: \.paywall) {
            PaywallFeature()
        }
    }
}
