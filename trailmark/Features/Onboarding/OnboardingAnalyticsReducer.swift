import ComposableArchitecture
import CoreLocation

struct OnboardingAnalyticsReducer: Reducer {
    @Dependency(\.telemetry) var telemetry

    func reduce(into state: inout OnboardingStore.State, action: OnboardingStore.Action) -> Effect<OnboardingStore.Action> {
        switch action {
        case .introCompleted:
            return .run { [telemetry] _ in
                telemetry.signal("Onboarding.started", [:])
            }

        case .requestLocationAuthorization:
            return .run { [telemetry] _ in
                telemetry.signal("Onboarding.locationRequested", [:])
            }

        case let .locationAuthorizationEvent(.didChangeAuthorization(status)):
            let statusName: String
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                statusName = "granted"
            case .denied:
                statusName = "denied"
            case .restricted:
                statusName = "restricted"
            default:
                return .none
            }
            return .run { [telemetry] _ in
                telemetry.signal("Onboarding.locationResult", ["status": statusName])
            }

        case .carouselCompleted:
            return .run { [telemetry] _ in
                telemetry.signal("Onboarding.completed", [:])
            }

        default:
            return .none
        }
    }
}
