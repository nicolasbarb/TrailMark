import Foundation
import ComposableArchitecture

@Reducer
struct MilestoneListFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        @Shared(.inMemory("editorMilestones")) var milestones: [Milestone] = []
    }

    enum Action: Equatable {
        case milestoneTapped(Milestone)

        enum Delegate: Equatable {
            case goToMilestone(Milestone)
        }
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .milestoneTapped(milestone):
                return .send(.delegate(.goToMilestone(milestone)))

            case .delegate:
                return .none
            }
        }
    }
}