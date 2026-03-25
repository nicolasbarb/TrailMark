import ComposableArchitecture

struct SettingsAnalyticsReducer: Reducer {
    @Dependency(\.telemetry) var telemetry

    func reduce(into state: inout SettingsStore.State, action: SettingsStore.Action) -> Effect<SettingsStore.Action> {
        switch action {
        case .upgradeTapped:
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.shown", ["source": "settings"])
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

        default:
            return .none
        }
    }
}
