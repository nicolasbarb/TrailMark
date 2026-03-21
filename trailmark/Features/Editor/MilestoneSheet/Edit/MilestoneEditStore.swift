import Foundation
import ComposableArchitecture

@Reducer
struct MilestoneEditStore {
    @ObservableState
    struct State: Equatable, Sendable {
        var selectedType: MilestoneType
        var personalMessage: String
        var name: String
        var isPlayingPreview = false
        var isEditing: Bool
        var distance: Double
        var elevation: Double
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case typeSelected(MilestoneType)
        case saveButtonTapped
        case deleteButtonTapped
        case dismissTapped
        case previewTTSTapped
        case stopTTSTapped
        case ttsFinished
    }

    @Dependency(\.speech) var speech

    private enum CancelID { case ttsPreview }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .onAppear:
                return .run { [speech] _ in
                    try? speech.configureAudioSession()
                }
            case let .typeSelected(type):
                state.selectedType = type
                return .none
            case .saveButtonTapped, .deleteButtonTapped:
                return .none
            case .dismissTapped:
                return .run { [speech] _ in
                    speech.stop()
                }
                .merge(with: .cancel(id: CancelID.ttsPreview))
            case .previewTTSTapped:
                guard !state.personalMessage.isEmpty else { return .none }
                state.isPlayingPreview = true
                let message = state.personalMessage
                return .run { send in
                    await speech.speak(message)
                    await send(.ttsFinished)
                }
                .cancellable(id: CancelID.ttsPreview)
            case .stopTTSTapped:
                state.isPlayingPreview = false
                return .run { [speech] _ in
                    speech.stop()
                }
                .merge(with: .cancel(id: CancelID.ttsPreview))
            case .ttsFinished:
                state.isPlayingPreview = false
                return .none
            }
        }
    }
}
