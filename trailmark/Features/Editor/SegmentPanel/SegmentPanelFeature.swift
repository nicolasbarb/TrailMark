import Foundation
import ComposableArchitecture

@Reducer
struct SegmentPanelFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var currentScrollIndex: Int = 0
        @Shared(.inMemory("editorMilestones")) var milestones: [Milestone] = []
        @Presents var milestoneList: MilestoneListFeature.State?
    }

    enum Action: Equatable {
        case scrollIndexChanged(Int)
        case addMilestoneTapped
        case listMilestonesTapped
        case milestoneList(PresentationAction<MilestoneListFeature.Action>)

        enum Delegate: Equatable {
            case addMilestoneTapped
            case goToMilestone(Milestone)
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
                state.milestoneList = MilestoneListFeature.State()
                return .none

            case .milestoneList(.presented(.delegate(let delegateAction))):
                switch delegateAction {
                case let .goToMilestone(milestone):
                    return .send(.delegate(.goToMilestone(milestone)))
                }

            case .milestoneList:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$milestoneList, action: \.milestoneList) {
            MilestoneListFeature()
        }
    }
}