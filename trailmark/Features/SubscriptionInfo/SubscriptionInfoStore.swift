import Foundation
import ComposableArchitecture

@Reducer
struct SubscriptionInfoStore {
    @ObservableState
    struct State: Equatable {
        var subscriptionInfo: SubscriptionInfo?
        var isLoading = true
        var showManageSheet = false
    }

    enum Action: Equatable {
        case onAppear
        case infoLoaded(SubscriptionInfo?)
        case manageSubscriptionTapped
        case manageSheetDismissed
        case closeButtonTapped
    }

    @Dependency(\.subscription) var subscription
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let info = await subscription.fetchSubscriptionInfo()
                    await send(.infoLoaded(info))
                }

            case let .infoLoaded(info):
                state.isLoading = false
                state.subscriptionInfo = info
                return .none

            case .manageSubscriptionTapped:
                state.showManageSheet = true
                return .none

            case .manageSheetDismissed:
                state.showManageSheet = false
                return .none

            case .closeButtonTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
