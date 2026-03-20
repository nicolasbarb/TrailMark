import ComposableArchitecture

struct TrailListAnalyticsReducer: Reducer {
    @Dependency(\.telemetry) var telemetry

    func reduce(into state: inout TrailListStore.State, action: TrailListStore.Action) -> Effect<TrailListStore.Action> {
        switch action {
        case .addButtonTapped:
            guard !state.isPremium && state.trails.count >= 1 else { return .none }
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.shown", ["source": "trailLimit"])
            }

        case ._checkFirstVisitPaywall:
            guard state.trailListVisitCount == 1 else { return .none }
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.shown", ["source": "firstVisit"])
            }

        case .renewTapped:
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.shown", ["source": "expired"])
            }

        case .destination(.presented(.paywall(.purchaseCompleted))):
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.purchaseCompleted", [:])
            }

        case .destination(.presented(.paywall(.restoreCompleted))):
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.restoreCompleted", [:])
            }

        case .destination(.presented(.paywall(.closeButtonTapped))):
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.dismissed", [:])
            }

        case .trailDeleted:
            return .run { [telemetry] _ in
                telemetry.signal("Trail.deleted", [:])
            }

        default:
            return .none
        }
    }
}
