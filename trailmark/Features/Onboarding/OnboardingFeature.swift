import CoreLocation
import ComposableArchitecture

@Reducer
struct OnboardingFeature {
    // MARK: - Cancel IDs

    private enum CancelID {
        case locationAuthorization
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var locationStatus: CLAuthorizationStatus = .notDetermined
        var isCompleted = false
    }

    // MARK: - Action

    enum Action: Equatable {
        case carouselCompleted
        case requestLocationAuthorization
        case locationAuthorizationChanged(CLAuthorizationStatus)
        case locationSkipped
    }

    // MARK: - Dependencies

    @Dependency(\.location) var location

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .carouselCompleted:
                state.isCompleted = true
                return .cancel(id: CancelID.locationAuthorization)

            case .requestLocationAuthorization:
                return .run { send in
                    let status = await location.requestAuthorization()
                    await send(.locationAuthorizationChanged(status))
                }
                .cancellable(id: CancelID.locationAuthorization)

            case let .locationAuthorizationChanged(status):
                state.locationStatus = status
                return .none

            case .locationSkipped:
                // Analytics ou autre logique si nécessaire
                return .none
            }
        }
    }
}

// MARK: - CLAuthorizationStatus Equatable

extension CLAuthorizationStatus: @retroactive Equatable {}
