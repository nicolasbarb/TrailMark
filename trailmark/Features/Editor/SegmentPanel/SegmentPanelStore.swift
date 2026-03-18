import Foundation
import ComposableArchitecture

@Reducer
struct SegmentPanelStore {
    @ObservableState
    struct State: Equatable, Sendable {
        var currentScrollIndex: Int = 0
        @Presents var milestoneList: MilestoneListStore.State?
    }

    enum Action: Equatable {
        case scrollIndexChanged(Int)
        case addMilestoneTapped
        case listMilestonesTapped
        case milestoneList(PresentationAction<MilestoneListStore.Action>)

        enum Delegate: Equatable {
            case addMilestoneTapped
            case goToMilestone(Milestone)
            case editMilestone(Milestone)
        }
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .scrollIndexChanged(index):
                state.currentScrollIndex = index
                return .none

            case .addMilestoneTapped:
                return .send(.delegate(.addMilestoneTapped))

            case .listMilestonesTapped:
                state.milestoneList = MilestoneListStore.State()
                return .none

            case let .milestoneList(.presented(.delegate(.goToMilestone(milestone)))):
                return .send(.delegate(.goToMilestone(milestone)))

            case let .milestoneList(.presented(.delegate(.editMilestone(milestone)))):
                return .send(.delegate(.editMilestone(milestone)))

            case .milestoneList:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$milestoneList, action: \.milestoneList) {
            MilestoneListStore()
        }
    }
}
