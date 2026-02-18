import Foundation
import ComposableArchitecture
import CoreLocation

// MARK: - CLAuthorizationStatus Debug

extension CLAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Cancel IDs (must be outside reducer for proper isolation)

private let trackingCancelID = "RunFeature.tracking"

@Reducer
struct RunFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        let trailId: Int64
        var trailDetail: TrailDetail?
        var isRunning = false
        var authorizationDenied = false
        var triggeredMilestoneIds: Set<Int64> = []
        var currentTTSMessage: String?
    }

    enum Action: Equatable, Sendable {
        case onAppear
        case trailLoaded(TrailDetail)
        case startButtonTapped
        case stopButtonTapped
        case authorizationResult(Int32) // CLAuthorizationStatus raw value
        case locationUpdated(Double, Double) // lat, lon
        case milestoneTriggered(Milestone)
        case ttsFinished
        case backTapped
    }

    @Dependency(\.database) var database
    @Dependency(\.location) var location
    @Dependency(\.speech) var speech
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                print("[Run] onAppear - chargement trail \(state.trailId)")
                return .run { [trailId = state.trailId] send in
                    if let detail = try await database.fetchTrailDetail(trailId) {
                        await send(.trailLoaded(detail))
                    }
                }

            case let .trailLoaded(detail):
                state.trailDetail = detail
                print("[Run] Trail chargé: \(detail.trail.name) - \(detail.milestones.count) jalons")
                return .none

            case .startButtonTapped:
                print("[Run] Bouton Start appuyé - demande permission GPS")
                return .run { send in
                    let status = await location.requestAuthorization()
                    await send(.authorizationResult(status.rawValue))
                }

            case let .authorizationResult(rawValue):
                let status = CLAuthorizationStatus(rawValue: rawValue) ?? .notDetermined
                print("[Run] Permission GPS: \(status.rawValue) (\(status.debugDescription))")
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    state.isRunning = true
                    state.authorizationDenied = false
                    print("[Run] ✅ Démarrage du tracking GPS")
                    return .run { [location, speech] send in
                        // Configure audio
                        try? speech.configureAudioSession()
                        print("[Run] Audio session configurée")

                        // Start tracking
                        for await loc in location.startTracking() {
                            await send(.locationUpdated(loc.coordinate.latitude, loc.coordinate.longitude))
                        }
                        print("[Run] Tracking stream terminé")
                    }
                    .cancellable(id: trackingCancelID)

                case .denied, .restricted:
                    state.authorizationDenied = true
                    print("[Run] ❌ Permission GPS refusée")
                    return .none

                default:
                    print("[Run] ⚠️ Permission GPS: statut inattendu")
                    return .none
                }

            case let .locationUpdated(lat, lon):
                guard let detail = state.trailDetail else { return .none }

                let currentLocation = CLLocation(latitude: lat, longitude: lon)
                print("[Run] 📍 Position: \(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))")

                // Check milestones
                var closestDistance: Double = .infinity
                var closestMilestone: Milestone?

                for milestone in detail.milestones {
                    guard let milestoneId = milestone.id,
                          !state.triggeredMilestoneIds.contains(milestoneId) else { continue }

                    let milestoneLocation = CLLocation(latitude: milestone.latitude, longitude: milestone.longitude)
                    let distance = currentLocation.distance(from: milestoneLocation)

                    if distance < closestDistance {
                        closestDistance = distance
                        closestMilestone = milestone
                    }

                    if distance < 30 {
                        state.triggeredMilestoneIds.insert(milestoneId)
                        print("[Run] 🎯 Jalon déclenché! Distance: \(Int(distance))m")
                        return .send(.milestoneTriggered(milestone))
                    }
                }

                if let closest = closestMilestone {
                    print("[Run] Jalon le plus proche: \(Int(closestDistance))m - \"\(closest.message.prefix(30))...\"")
                }

                return .none

            case let .milestoneTriggered(milestone):
                state.currentTTSMessage = milestone.message
                print("[Run] 🔊 TTS démarré: \"\(milestone.message)\"")
                return .run { [speech] send in
                    await speech.speak(milestone.message)
                    await send(.ttsFinished)
                }

            case .ttsFinished:
                state.currentTTSMessage = nil
                print("[Run] 🔇 TTS terminé")
                return .none

            case .stopButtonTapped:
                print("[Run] ⏹️ Arrêt du guidage (bouton stop)")
                state.isRunning = false
                state.currentTTSMessage = nil
                return .merge(
                    .cancel(id: trackingCancelID),
                    .run { [location, speech, dismiss] _ in
                        location.stopTracking()
                        speech.stop()
                        print("[Run] Tracking et TTS arrêtés")
                        await dismiss()
                    }
                )

            case .backTapped:
                print("[Run] ⬅️ Bouton retour appuyé (isRunning: \(state.isRunning))")
                if state.isRunning {
                    return .merge(
                        .cancel(id: trackingCancelID),
                        .run { [location, speech, dismiss] _ in
                            location.stopTracking()
                            speech.stop()
                            print("[Run] Tracking et TTS arrêtés")
                            await dismiss()
                        }
                    )
                } else {
                    return .run { _ in
                        await dismiss()
                    }
                }
            }
        }
    }
}
