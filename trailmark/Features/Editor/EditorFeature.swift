import Foundation
import ComposableArchitecture
import CoreLocation

// MARK: - MilestoneSheet Reducer

@Reducer
struct MilestoneSheetFeature {
    @ObservableState
    struct State: Equatable, Sendable, Identifiable {
        var id: UUID = UUID()
        var editingMilestone: Milestone?
        var pointIndex: Int
        var latitude: Double
        var longitude: Double
        var elevation: Double
        var distance: Double
        var selectedType: MilestoneType
        var message: String
        var name: String

        var isEditing: Bool { editingMilestone != nil }
    }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case typeSelected(MilestoneType)
        case saveButtonTapped
        case dismissTapped
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .typeSelected(let type):
                state.selectedType = type
                return .none
            case .saveButtonTapped:
                return .none
            case .dismissTapped:
                return .none
            }
        }
    }
}

// MARK: - Editor Tab

enum EditorTab: Equatable, Sendable {
    case map
    case milestones
}

// MARK: - Editor Feature

@Reducer
struct EditorFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        let trailId: Int64
        var trailDetail: TrailDetail?
        var selectedTab: EditorTab = .map
        var cursorPointIndex: Int?
        var milestones: [Milestone] = []
        var originalMilestones: [Milestone] = []
        var isRenamingTrail = false
        var editedTrailName = ""
        var isSelectingMilestones = false
        var selectedMilestoneIndices: Set<Int> = []
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var milestoneSheet: MilestoneSheetFeature.State?

        var hasMilestoneChanges: Bool {
            milestones != originalMilestones
        }
    }

    enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case trailLoaded(TrailDetail)
        case tabSelected(EditorTab)
        case cursorMoved(Int?)
        case profileTapped(Int)
        case saveButtonTapped
        case savingCompleted
        case milestoneSheet(PresentationAction<MilestoneSheetFeature.Action>)
        case deleteMilestone(Int)
        case editMilestone(Milestone)
        case toggleSelectionMode
        case toggleMilestoneSelection(Int)
        case deleteSelectedMilestones
        case backTapped
        case deleteTrailButtonTapped
        case renameButtonTapped
        case renameConfirmed
        case renameCancelled
        case trailNameUpdated(String)
        case alert(PresentationAction<Alert>)

        @CasePathable
        enum Alert: Sendable {
            case confirmDelete
        }
    }

    @Dependency(\.database) var database
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { [trailId = state.trailId] send in
                    if let detail = try await database.fetchTrailDetail(trailId) {
                        await send(.trailLoaded(detail))
                    }
                }

            case let .trailLoaded(detail):
                state.trailDetail = detail
                state.milestones = detail.milestones
                state.originalMilestones = detail.milestones
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case let .cursorMoved(index):
                state.cursorPointIndex = index
                return .none

            case let .profileTapped(pointIndex):
                guard let detail = state.trailDetail,
                      pointIndex < detail.trackPoints.count else { return .none }

                let point = detail.trackPoints[pointIndex]

                // Auto-detect type based on elevation change
                let detectedType = Self.detectMilestoneType(
                    at: pointIndex,
                    trackPoints: detail.trackPoints
                )

                state.milestoneSheet = MilestoneSheetFeature.State(
                    editingMilestone: nil,
                    pointIndex: pointIndex,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    elevation: point.elevation,
                    distance: point.distance,
                    selectedType: detectedType,
                    message: "",
                    name: ""
                )
                return .none

            case let .editMilestone(milestone):
                state.milestoneSheet = MilestoneSheetFeature.State(
                    editingMilestone: milestone,
                    pointIndex: milestone.pointIndex,
                    latitude: milestone.latitude,
                    longitude: milestone.longitude,
                    elevation: milestone.elevation,
                    distance: milestone.distance,
                    selectedType: milestone.milestoneType,
                    message: milestone.message,
                    name: milestone.name ?? ""
                )
                return .none

            case let .deleteMilestone(index):
                guard index < state.milestones.count else { return .none }
                state.milestones.remove(at: index)
                return .run { [trailId = state.trailId, milestones = state.milestones] send in
                    try await database.saveMilestones(trailId, milestones)
                    await send(.savingCompleted)
                }

            case .toggleSelectionMode:
                state.isSelectingMilestones.toggle()
                if !state.isSelectingMilestones {
                    state.selectedMilestoneIndices.removeAll()
                }
                return .none

            case let .toggleMilestoneSelection(index):
                if state.selectedMilestoneIndices.contains(index) {
                    state.selectedMilestoneIndices.remove(index)
                } else {
                    state.selectedMilestoneIndices.insert(index)
                }
                return .none

            case .deleteSelectedMilestones:
                let indicesToDelete = state.selectedMilestoneIndices.sorted(by: >)
                for index in indicesToDelete {
                    if index < state.milestones.count {
                        state.milestones.remove(at: index)
                    }
                }
                state.selectedMilestoneIndices.removeAll()
                state.isSelectingMilestones = false
                return .run { [trailId = state.trailId, milestones = state.milestones] send in
                    try await database.saveMilestones(trailId, milestones)
                    await send(.savingCompleted)
                }

            case .saveButtonTapped:
                return .run { [trailId = state.trailId, milestones = state.milestones] send in
                    try await database.saveMilestones(trailId, milestones)
                    await send(.savingCompleted)
                }

            case .savingCompleted:
                state.originalMilestones = state.milestones
                return .none

            case .milestoneSheet(.presented(.typeSelected(let type))):
                state.milestoneSheet?.selectedType = type
                return .none

            case .milestoneSheet(.presented(.saveButtonTapped)):
                guard let sheet = state.milestoneSheet else { return .none }

                let message = sheet.message.isEmpty ? sheet.selectedType.label : sheet.message
                let name: String? = sheet.name.isEmpty ? nil : sheet.name

                if let existingMilestone = sheet.editingMilestone,
                   let index = state.milestones.firstIndex(where: { $0.id == existingMilestone.id }) {
                    // Update existing milestone
                    state.milestones[index].type = sheet.selectedType.rawValue
                    state.milestones[index].message = message
                    state.milestones[index].name = name
                } else {
                    // Create new milestone
                    let milestone = Milestone(
                        id: nil,
                        trailId: state.trailId,
                        pointIndex: sheet.pointIndex,
                        latitude: sheet.latitude,
                        longitude: sheet.longitude,
                        elevation: sheet.elevation,
                        distance: sheet.distance,
                        type: sheet.selectedType,
                        message: message,
                        name: name
                    )
                    state.milestones.append(milestone)
                    // Sort by distance
                    state.milestones.sort { $0.distance < $1.distance }
                }

                state.milestoneSheet = nil
                return .run { [trailId = state.trailId, milestones = state.milestones] send in
                    try await database.saveMilestones(trailId, milestones)
                    await send(.savingCompleted)
                }

            case .milestoneSheet(.presented(.dismissTapped)):
                state.milestoneSheet = nil
                return .none

            case .milestoneSheet(.presented(.binding)):
                return .none

            case .milestoneSheet(.dismiss):
                return .none

            case .backTapped:
                return .run { _ in
                    await dismiss()
                }

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
                    TextState("Cette action supprimera définitivement le parcours et tous ses jalons.")
                }
                return .none

            case .renameButtonTapped:
                state.editedTrailName = state.trailDetail?.trail.name ?? ""
                state.isRenamingTrail = true
                return .none

            case .renameConfirmed:
                state.isRenamingTrail = false
                let newName = state.editedTrailName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !newName.isEmpty else { return .none }
                return .run { [trailId = state.trailId] send in
                    try await database.updateTrailName(trailId, newName)
                    await send(.trailNameUpdated(newName))
                }

            case .renameCancelled:
                state.isRenamingTrail = false
                return .none

            case let .trailNameUpdated(newName):
                state.trailDetail?.trail.name = newName
                return .none

            case .alert(.presented(.confirmDelete)):
                return .run { [trailId = state.trailId] _ in
                    try await database.deleteTrail(trailId)
                    await dismiss()
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$milestoneSheet, action: \.milestoneSheet) {
            MilestoneSheetFeature()
        }
    }

    // MARK: - Helpers

    private static func detectMilestoneType(at index: Int, trackPoints: [TrackPoint]) -> MilestoneType {
        let lookAhead = 20
        let futureIndex = min(index + lookAhead, trackPoints.count - 1)

        guard futureIndex > index else { return .plat }

        let currentElevation = trackPoints[index].elevation
        let futureElevation = trackPoints[futureIndex].elevation
        let delta = futureElevation - currentElevation

        if delta > 10 {
            return .montee
        } else if delta < -10 {
            return .descente
        } else {
            return .plat
        }
    }
}
