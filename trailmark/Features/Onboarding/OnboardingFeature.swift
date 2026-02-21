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
        var currentPhase: Phase = .intro
        var locationStatus: CLAuthorizationStatus = .notDetermined
        var isLocationSuccess = false
        var isCompleted = false

        enum Phase: Equatable {
            case intro
            case carousel
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case introCompleted
        case carouselCompleted
        case requestLocationAuthorization
        case locationAuthorizationEvent(LocationClient.DelegateEvent)
        case locationSuccessAnimationCompleted
        case locationSkipped
    }

    // MARK: - Dependencies

    @Dependency(\.location) var location

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .introCompleted:
                state.currentPhase = .carousel
                return .none

            case .carouselCompleted:
                state.isCompleted = true
                return .cancel(id: CancelID.locationAuthorization)

            case .requestLocationAuthorization:
                print("[Onboarding] requestLocationAuthorization action received")
                return .run { [location] send in
                    // CLLocationManager requires main thread for delegate callbacks
                    let delegateStream = await MainActor.run {
                        let stream = location.delegate()
                        print("[Onboarding] Delegate stream created on main thread")
                        location.requestWhenInUseAuthorization()
                        print("[Onboarding] requestWhenInUseAuthorization called")
                        return stream
                    }

                    // Listen for authorization changes
                    for await event in delegateStream {
                        print("[Onboarding] Received event: \(event)")
                        await send(.locationAuthorizationEvent(event))
                    }
                    print("[Onboarding] Delegate listener ended")
                }
                .cancellable(id: CancelID.locationAuthorization)

            case let .locationAuthorizationEvent(event):
                switch event {
                case let .didChangeAuthorization(status):
                    state.locationStatus = status
                    // Auto-complete onboarding when permission is granted or denied
                    switch status {
                    case .authorizedWhenInUse, .authorizedAlways:
                        state.isLocationSuccess = true
                        // Wait for success animation before completing
                        return .run { send in
                            try? await Task.sleep(for: .seconds(2.5))
                            await send(.locationSuccessAnimationCompleted)
                        }
                    case .denied, .restricted:
                        // Track that location was skipped/denied for analytics
                        return .concatenate(
                            .send(.locationSkipped),
                            .send(.carouselCompleted)
                        )
                    default:
                        return .none
                    }
                }

            case .locationSuccessAnimationCompleted:
                return .send(.carouselCompleted)

            case .locationSkipped:
                // Analytics ou autre logique si nécessaire
                return .none
            }
        }
    }
}

// MARK: - CLAuthorizationStatus Equatable

extension CLAuthorizationStatus: @retroactive Equatable {}
