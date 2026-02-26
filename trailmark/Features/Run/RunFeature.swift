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

        // Debug
        var showDebugView = false
        var currentLatitude: Double?
        var currentLongitude: Double?
        var closestMilestoneDistance: Int?
        var closestMilestoneMessage: String?
        var locationUpdateCount: Int = 0
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
        case toggleDebugView

        // MARK: - Internal actions (for testability)
        case _loadTrailDetail
        case _checkLocationAuthorization
        case _configureAudioSession
        case _startLocationTracking
        case _updateDebugLocation(Double, Double)
        case _checkMilestoneProximity(Double, Double)
        case _speakMessage(String)
        case _stopTracking
        case _stopSpeech
        case _dismiss
    }

    @Dependency(\.database) var database
    @Dependency(\.location) var location
    @Dependency(\.speech) var speech
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            // MARK: - Public actions

            case .onAppear:
                print("[Run] onAppear - chargement trail \(state.trailId)")
                return .send(._loadTrailDetail)

            case let .trailLoaded(detail):
                state.trailDetail = detail
                print("[Run] Trail chargé: \(detail.trail.name) - \(detail.milestones.count) jalons")
                return .none

            case .startButtonTapped:
                print("[Run] Bouton Start appuyé - vérification permission GPS")
                return .send(._checkLocationAuthorization)

            case let .authorizationResult(rawValue):
                let status = CLAuthorizationStatus(rawValue: rawValue) ?? .notDetermined
                print("[Run] Permission GPS: \(status.rawValue) (\(status.debugDescription))")
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    state.isRunning = true
                    state.authorizationDenied = false
                    print("[Run] ✅ Démarrage du tracking GPS")
                    return .concatenate(
                        .send(._configureAudioSession),
                        .send(._startLocationTracking)
                    )

                case .denied, .restricted:
                    state.authorizationDenied = true
                    print("[Run] ❌ Permission GPS refusée")
                    return .none

                default:
                    print("[Run] ⚠️ Permission GPS: statut inattendu")
                    return .none
                }

            case let .locationUpdated(lat, lon):
                guard state.trailDetail != nil else { return .none }
                print("[Run] 📍 Position: \(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))")
                return .concatenate(
                    .send(._updateDebugLocation(lat, lon)),
                    .send(._checkMilestoneProximity(lat, lon))
                )

            case let .milestoneTriggered(milestone):
                state.currentTTSMessage = milestone.message
                print("[Run] 🔊 TTS démarré: \"\(milestone.message)\"")
                return .send(._speakMessage(milestone.message))

            case .ttsFinished:
                state.currentTTSMessage = nil
                print("[Run] 🔇 TTS terminé")
                return .none

            case .stopButtonTapped:
                print("[Run] ⏹️ Arrêt du guidage (bouton stop)")
                state.isRunning = false
                state.currentTTSMessage = nil
                return .concatenate(
                    .send(._stopTracking),
                    .send(._stopSpeech),
                    .send(._dismiss)
                )

            case .backTapped:
                print("[Run] ⬅️ Bouton retour appuyé (isRunning: \(state.isRunning))")
                if state.isRunning {
                    return .concatenate(
                        .send(._stopTracking),
                        .send(._stopSpeech),
                        .send(._dismiss)
                    )
                } else {
                    return .send(._dismiss)
                }

            case .toggleDebugView:
                state.showDebugView.toggle()
                print("[Run] Debug view: \(state.showDebugView ? "ON" : "OFF")")
                return .none

            // MARK: - Internal actions (for testability)

            case ._loadTrailDetail:
                return .run { [trailId = state.trailId] send in
                    if let detail = try await database.fetchTrailDetail(trailId) {
                        await send(.trailLoaded(detail))
                    }
                }

            case ._checkLocationAuthorization:
                let status = location.authorizationStatus()
                return .send(.authorizationResult(status.rawValue))

            case ._configureAudioSession:
                return .run { [speech] _ in
                    try? speech.configureAudioSession()
                    print("[Run] Audio session configurée")
                }

            case ._startLocationTracking:
                return .run { [location] send in
                    for await loc in location.startTracking() {
                        await send(.locationUpdated(loc.coordinate.latitude, loc.coordinate.longitude))
                    }
                    print("[Run] Tracking stream terminé")
                }
                .cancellable(id: trackingCancelID)

            case let ._updateDebugLocation(lat, lon):
                state.currentLatitude = lat
                state.currentLongitude = lon
                state.locationUpdateCount += 1
                return .none

            case let ._checkMilestoneProximity(lat, lon):
                guard let detail = state.trailDetail else { return .none }

                let currentLocation = CLLocation(latitude: lat, longitude: lon)

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

                // Update debug info
                if let closest = closestMilestone {
                    state.closestMilestoneDistance = Int(closestDistance)
                    state.closestMilestoneMessage = closest.message
                    print("[Run] Jalon le plus proche: \(Int(closestDistance))m - \"\(closest.message.prefix(30))...\"")
                } else {
                    state.closestMilestoneDistance = nil
                    state.closestMilestoneMessage = nil
                }

                return .none

            case let ._speakMessage(message):
                return .run { [speech] send in
                    await speech.speak(message)
                    await send(.ttsFinished)
                }

            case ._stopTracking:
                return .merge(
                    .cancel(id: trackingCancelID),
                    .run { [location] _ in
                        location.stopTracking()
                        print("[Run] Tracking arrêté")
                    }
                )

            case ._stopSpeech:
                return .run { [speech] _ in
                    speech.stop()
                    print("[Run] TTS arrêté")
                }

            case ._dismiss:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }
}
