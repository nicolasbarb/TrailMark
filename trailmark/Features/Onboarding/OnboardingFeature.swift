import Foundation
import CoreLocation
import UIKit
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
        var currentPhase: Phase = .carousel
        var locationStatus: CLAuthorizationStatus = .notDetermined
        var isCompleted = false

        enum Phase: Equatable {
            case carousel
            case paywall
        }
    }

    // MARK: - Action

    enum Action: Equatable {
        case carouselCompleted
        case requestLocationAuthorization
        case locationAuthorizationChanged(CLAuthorizationStatus)
        case openSettings
        case locationSkipped
        case skipPaywall
        case paywallCompleted
        case completeOnboarding
    }

    // MARK: - Dependencies

    @Dependency(\.location) var location
    @Dependency(\.openURL) var openURL

    // MARK: - Reducer

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .carouselCompleted:
                state.currentPhase = .paywall
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

            case .openSettings:
                return .run { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        await openURL(url)
                    }
                }

            case .locationSkipped:
                // Analytics ou autre logique si nécessaire
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

// MARK: - CLAuthorizationStatus Equatable

extension CLAuthorizationStatus: @retroactive Equatable {}
