import Foundation
import ComposableArchitecture

@Reducer
struct SettingsStore {
    @ObservableState
    struct State: Equatable {
        @Shared(.inMemory("isPremium")) var isPremium = false
        @Presents var destination: Destination.State?
    }

    enum Action: Equatable {
        case upgradeTapped
        case destination(PresentationAction<Destination.Action>)
    }

    var body: some Reducer<State, Action> {
        SettingsAnalyticsReducer()

        Reduce { state, action in
            switch action {
            case .upgradeTapped:
                state.destination = .paywall(PaywallStore.State())
                return .none

            case .destination(.presented(.paywall(.purchaseCompleted))),
                 .destination(.presented(.paywall(.restoreCompleted))):
                state.$isPremium.withLock { $0 = true }
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }

    // MARK: - Destination

    @Reducer
    struct Destination {
        @ObservableState
        enum State: Equatable {
            case paywall(PaywallStore.State)
            case subscriptionInfo(SubscriptionInfoStore.State)
        }

        enum Action: Equatable {
            case paywall(PaywallStore.Action)
            case subscriptionInfo(SubscriptionInfoStore.Action)
        }

        var body: some Reducer<State, Action> {
            Scope(state: \.paywall, action: \.paywall) {
                PaywallStore()
            }
            Scope(state: \.subscriptionInfo, action: \.subscriptionInfo) {
                SubscriptionInfoStore()
            }
        }
    }
}
