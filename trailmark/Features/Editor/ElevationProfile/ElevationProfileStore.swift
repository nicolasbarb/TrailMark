import Foundation
import ComposableArchitecture

@Reducer
struct ElevationProfileStore {
    @ObservableState
    struct State: Equatable, Sendable {
        var cursorPointIndex: Int?
        var scrolledPointIndex: Int = 0
    }

    enum Action: Equatable {
        case cursorMoved(Int?)
        case scrollPositionChanged(Int)
        case profileTapped(Int)
        case milestoneTapped(Milestone)

        enum Delegate: Equatable {
            case profileTapped(Int)
            case milestoneTapped(Milestone)
            case editMilestone(Milestone)
        }
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .cursorMoved(index):
                state.cursorPointIndex = index
                return .none

            case let .scrollPositionChanged(index):
                state.scrolledPointIndex = index
                return .none

            case let .profileTapped(index):
                return .send(.delegate(.profileTapped(index)))

            case let .milestoneTapped(milestone):
                return .send(.delegate(.milestoneTapped(milestone)))

            case .delegate:
                return .none
            }
        }
    }
}
