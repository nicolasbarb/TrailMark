import Foundation
import ComposableArchitecture

@Reducer
struct PaywallFeature {
    @ObservableState
    struct State: Equatable {
        var purchaseSucceeded = false
    }

    enum Action: Equatable {
        case purchaseCompleted
        case restoreCompleted
        case closeButtonTapped
    }

    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .purchaseCompleted:
                state.purchaseSucceeded = true
                return .none

            case .restoreCompleted:
                state.purchaseSucceeded = true
                return .none

            case .closeButtonTapped:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }
}
