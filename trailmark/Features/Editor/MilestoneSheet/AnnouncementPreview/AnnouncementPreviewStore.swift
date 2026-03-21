import Foundation
import ComposableArchitecture

@Reducer
struct AnnouncementPreviewStore {
    @ObservableState
    struct State: Equatable, Sendable {
        var autoMessage: String
        @Shared(.inMemory("isPremium")) var isPremium = false
    }

    enum Action: Equatable {
        case useAutoMessage
        case writeOwnMessage
        case unlockTapped

        enum Delegate: Equatable {
            case choseAutoMessage(String)
            case choseWriteOwn
            case unlockRequested
        }
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .useAutoMessage:
                return .send(.delegate(.choseAutoMessage(state.autoMessage)))

            case .writeOwnMessage:
                return .send(.delegate(.choseWriteOwn))

            case .unlockTapped:
                return .send(.delegate(.unlockRequested))

            case .delegate:
                return .none
            }
        }
    }
}
