import Foundation
import CoreLocation
import ComposableArchitecture

@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        var currentPhase: Phase = .carousel
        var locationAuthorizationStatus: LocationAuthorizationStatus = .notDetermined
        var isCompleted = false

        enum Phase: Equatable {
            case carousel
            case paywall
        }

        enum LocationAuthorizationStatus: Equatable {
            case notDetermined
            case authorized
            case denied
        }
    }

    enum Action: Equatable {
        case carouselCompleted
        case requestLocationAuthorization
        case locationAuthorizationChanged(State.LocationAuthorizationStatus)
        case skipPaywall
        case paywallCompleted
        case completeOnboarding
    }

    @Dependency(\.location) var location

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .carouselCompleted:
                state.currentPhase = .paywall
                return .none

            case .requestLocationAuthorization:
                return .run { send in
                    let status = await location.requestAuthorization()
                    switch status {
                    case .authorizedAlways, .authorizedWhenInUse:
                        await send(.locationAuthorizationChanged(.authorized))
                    case .denied, .restricted:
                        await send(.locationAuthorizationChanged(.denied))
                    case .notDetermined:
                        await send(.locationAuthorizationChanged(.notDetermined))
                    @unknown default:
                        await send(.locationAuthorizationChanged(.notDetermined))
                    }
                }

            case let .locationAuthorizationChanged(status):
                state.locationAuthorizationStatus = status
                return .none

            case .skipPaywall:
                return .send(.completeOnboarding)

            case .paywallCompleted:
                return .send(.completeOnboarding)

            case .completeOnboarding:
                state.isCompleted = true
                return .none
            }
        }
    }
}
