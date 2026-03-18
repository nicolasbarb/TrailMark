import Foundation
import ComposableArchitecture

@Reducer
struct MilestoneListStore {
    @ObservableState
    struct State: Equatable, Sendable {
        // Milestones are passed from parent, not @Shared
    }

    enum Action: Equatable {
        case milestoneTapped(Milestone)

        enum Delegate: Equatable {
            case goToMilestone(Milestone)
            case editMilestone(Milestone)
        }
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .milestoneTapped(milestone):
                return .merge(
                    .send(.delegate(.goToMilestone(milestone))),
                    .send(.delegate(.editMilestone(milestone)))
                )

            case .delegate:
                return .none
            }
        }
    }
}
