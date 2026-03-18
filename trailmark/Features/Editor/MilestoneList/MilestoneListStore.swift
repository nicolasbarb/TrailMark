import Foundation
import ComposableArchitecture

@Reducer
struct MilestoneListStore {
    @ObservableState
    struct State: Equatable, Sendable {
        @Presents var milestoneSheet: MilestoneSheetStore.State?
    }

    enum Action: Equatable {
        case milestoneTapped(Milestone)
        case milestoneSheet(PresentationAction<MilestoneSheetStore.Action>)

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
                // Delegate to parent to compute autoMessage and set sheet state
                return .merge(
                    .send(.delegate(.goToMilestone(milestone))),
                    .send(.delegate(.editMilestone(milestone)))
                )

            case .milestoneSheet:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$milestoneSheet, action: \.milestoneSheet) {
            MilestoneSheetStore()
        }
    }
}
