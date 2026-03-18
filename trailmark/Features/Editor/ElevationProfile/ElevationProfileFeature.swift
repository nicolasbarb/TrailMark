import Foundation
import ComposableArchitecture

@Reducer
struct ElevationProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var cursorPointIndex: Int?
        var scrolledPointIndex: Int = 0
        @Shared(.inMemory("editorTrailDetail")) var trailDetail: TrailDetail?
        @Shared(.inMemory("editorMilestones")) var milestones: [Milestone] = []
    }

    enum Action: Equatable {
        case cursorMoved(Int?)
        case scrollPositionChanged(Int)
        case profileTapped(Int)
        case milestoneTapped(Milestone)

        // Delegate actions for parent
        enum Delegate: Equatable {
            case profileTapped(Int)
            case milestoneTapped(Milestone)
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