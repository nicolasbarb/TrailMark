import Foundation
import ComposableArchitecture

@Reducer
struct TrailMetadataFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var isRenamingTrail = false
        var editedTrailName = ""
        @Shared(.inMemory("editorTrailDetail")) var trailDetail: TrailDetail?
        @Shared(.inMemory("editorTrailId")) var trailId: Int64?
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case renameButtonTapped
        case renameConfirmed
        case renameCancelled
        case deleteTrailButtonTapped
        case trailNameUpdated(String)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Sendable {
            case confirmDelete
        }

        enum Delegate: Equatable {
            case trailDeleted
        }
        case delegate(Delegate)
    }

    @Dependency(\.database) var database
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .renameButtonTapped:
                state.editedTrailName = state.trailDetail?.trail.name ?? ""
                state.isRenamingTrail = true
                return .none

            case .renameConfirmed:
                state.isRenamingTrail = false
                let newName = state.editedTrailName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !newName.isEmpty else { return .none }
                guard let trailId = state.trailId else {
                    state.$trailDetail.withLock { $0?.trail.name = newName }
                    return .none
                }
                return .run { send in
                    try await database.updateTrailName(trailId, newName)
                    await send(.trailNameUpdated(newName))
                }

            case .renameCancelled:
                state.isRenamingTrail = false
                return .none

            case let .trailNameUpdated(newName):
                state.$trailDetail.withLock { $0?.trail.name = newName }
                return .none

            case .deleteTrailButtonTapped:
                state.alert = AlertState {
                    TextState("Supprimer ce parcours ?")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("Annuler")
                    }
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("Supprimer")
                    }
                } message: {
                    TextState("Cette action supprimera définitivement le parcours et tous ses repères.")
                }
                return .none

            case .alert(.presented(.confirmDelete)):
                guard let trailId = state.trailId else {
                    return .run { _ in await dismiss() }
                }
                return .run { send in
                    try await database.deleteTrail(trailId)
                    await send(.delegate(.trailDeleted))
                }

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}