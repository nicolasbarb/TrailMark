import Foundation
import ComposableArchitecture
import CoreLocation

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
                return .run { [trailId = state.trailId] send in
                    if let detail = try await database.fetchTrailDetail(trailId) {
                        await send(.trailLoaded(detail))
                    }
                }

            case let .trailLoaded(detail):
                state.trailDetail = detail
                return .none

            case .startButtonTapped:
                return .run { send in
                    let status = await location.requestAuthorization()
                    await send(.authorizationResult(status.rawValue))
                }

            case let .authorizationResult(rawValue):
                let status = CLAuthorizationStatus(rawValue: rawValue) ?? .notDetermined
                switch status {
                case .authorizedAlways, .authorizedWhenInUse:
                    state.isRunning = true
                    state.authorizationDenied = false
                    return .run { [location, speech] send in
                        // Configure audio
                        try? speech.configureAudioSession()

                        // Start tracking
                        for await loc in location.startTracking() {
                            await send(.locationUpdated(loc.coordinate.latitude, loc.coordinate.longitude))
                        }
                    }
                    .cancellable(id: trackingCancelID)

                case .denied, .restricted:
                    state.authorizationDenied = true
                    return .none

                default:
                    return .none
                }

            case let .locationUpdated(lat, lon):
                guard let detail = state.trailDetail else { return .none }

                let currentLocation = CLLocation(latitude: lat, longitude: lon)

                // Check milestones
                for milestone in detail.milestones {
                    guard let milestoneId = milestone.id,
                          !state.triggeredMilestoneIds.contains(milestoneId) else { continue }

                    let milestoneLocation = CLLocation(latitude: milestone.latitude, longitude: milestone.longitude)
                    let distance = currentLocation.distance(from: milestoneLocation)

                    if distance < 30 {
                        state.triggeredMilestoneIds.insert(milestoneId)
                        return .send(.milestoneTriggered(milestone))
                    }
                }

                return .none

            case let .milestoneTriggered(milestone):
                state.currentTTSMessage = milestone.message
                return .run { [speech] send in
                    await speech.speak(milestone.message)
                    await send(.ttsFinished)
                }

            case .ttsFinished:
                state.currentTTSMessage = nil
                return .none

            case .stopButtonTapped:
                state.isRunning = false
                state.currentTTSMessage = nil
                return .merge(
                    .cancel(id: trackingCancelID),
                    .run { [location, speech, dismiss] _ in
                        location.stopTracking()
                        speech.stop()
                        await dismiss()
                    }
                )

            case .backTapped:
                if state.isRunning {
                    return .merge(
                        .cancel(id: trackingCancelID),
                        .run { [location, speech, dismiss] _ in
                            location.stopTracking()
                            speech.stop()
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
