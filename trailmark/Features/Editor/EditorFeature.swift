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

    enum Action: BindableAction, Equatable {
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

// MARK: - Pending Trail Data (données non sauvegardées)

struct PendingTrailData: Equatable, Sendable {
    var trail: Trail
    var trackPoints: [TrackPoint]
    var detectedMilestones: [Milestone]
}

// MARK: - Editor Feature

@Reducer
struct EditorFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        // Mode: soit trailId (existant), soit pendingData (nouveau)
        var trailId: Int64?
        var pendingData: PendingTrailData?

        var trailDetail: TrailDetail?
        var selectedTab: EditorTab = .map
        var cursorPointIndex: Int?
        var milestones: [Milestone] = []
        var originalMilestones: [Milestone] = []
        var isRenamingTrail = false
        var editedTrailName = ""
        var isSelectingMilestones = false
        var selectedMilestoneIndices: Set<Int> = []
        var isSavingInBackground = false
        @Presents var alert: AlertState<Action.Alert>?
        @Presents var milestoneSheet: MilestoneSheetFeature.State?

        var hasMilestoneChanges: Bool {
            milestones != originalMilestones
        }

        // Init pour un trail existant
        init(trailId: Int64) {
            self.trailId = trailId
            self.pendingData = nil
        }

        // Init pour un nouveau trail (données en mémoire)
        init(pendingData: PendingTrailData) {
            self.trailId = nil
            self.pendingData = pendingData
        }
    }

    enum Action: BindableAction, Equatable {
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

        // Background save
        case backgroundSaveCompleted(Trail)
        case backgroundSaveFailed

        @CasePathable
        enum Alert: Sendable {
            case confirmDelete
        }

        // MARK: - Internal actions (for testability)
        case _loadTrailDetail
        case _loadPendingData
        case _saveMilestones
        case _removeMilestoneAt(Int)
        case _removeSelectedMilestones
        case _addMilestone(Milestone)
        case _updateMilestone(Int64, MilestoneType, String, String?)
        case _updateTrailName(String)
        case _deleteTrail
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
                // Mode 1: Trail existant - charger depuis la DB
                if state.trailId != nil {
                    return .send(._loadTrailDetail)
                }
                // Mode 2: Nouveau trail - utiliser les données en mémoire
                if state.pendingData != nil {
                    return .send(._loadPendingData)
                }
                return .none

            case ._loadTrailDetail:
                return .run { [trailId = state.trailId] send in
                    if let trailId, let detail = try await database.fetchTrailDetail(trailId) {
                        await send(.trailLoaded(detail))
                    }
                }

            case ._loadPendingData:
                guard let pending = state.pendingData else { return .none }

                // Créer un TrailDetail temporaire pour l'affichage
                let detail = TrailDetail(
                    trail: pending.trail,
                    trackPoints: pending.trackPoints,
                    milestones: pending.detectedMilestones
                )
                state.trailDetail = detail
                state.milestones = pending.detectedMilestones
                state.originalMilestones = pending.detectedMilestones
                state.isSavingInBackground = true

                // Lancer la sauvegarde en arrière-plan
                return .run { [pending] send in
                    do {
                        // 1. Sauvegarder le trail et les trackpoints
                        let savedTrail = try await database.insertTrail(pending.trail, pending.trackPoints)

                        // 2. Sauvegarder les milestones si présents
                        if let trailId = savedTrail.id, !pending.detectedMilestones.isEmpty {
                            // Mettre à jour les milestones avec le bon trailId
                            let milestonesWithTrailId = pending.detectedMilestones.map { milestone in
                                Milestone(
                                    id: nil,
                                    trailId: trailId,
                                    pointIndex: milestone.pointIndex,
                                    latitude: milestone.latitude,
                                    longitude: milestone.longitude,
                                    elevation: milestone.elevation,
                                    distance: milestone.distance,
                                    type: milestone.milestoneType,
                                    message: milestone.message,
                                    name: milestone.name
                                )
                            }
                            try await database.saveMilestones(trailId, milestonesWithTrailId)
                        }

                        await send(.backgroundSaveCompleted(savedTrail))
                    } catch {
                        await send(.backgroundSaveFailed)
                    }
                }

            case let .trailLoaded(detail):
                state.trailDetail = detail
                state.milestones = detail.milestones
                state.originalMilestones = detail.milestones
                return .none

            case let .backgroundSaveCompleted(savedTrail):
                state.isSavingInBackground = false
                state.trailId = savedTrail.id
                state.pendingData = nil
                // Mettre à jour le trail dans le detail
                state.trailDetail?.trail = savedTrail
                return .none

            case .backgroundSaveFailed:
                state.isSavingInBackground = false
                // TODO: Gérer l'erreur (afficher une alerte ?)
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
                return .concatenate(
                    .send(._removeMilestoneAt(index)),
                    .send(._saveMilestones)
                )

            case let ._removeMilestoneAt(index):
                guard index < state.milestones.count else { return .none }
                state.milestones.remove(at: index)
                return .none

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
                return .concatenate(
                    .send(._removeSelectedMilestones),
                    .send(._saveMilestones)
                )

            case ._removeSelectedMilestones:
                let indicesToDelete = state.selectedMilestoneIndices.sorted(by: >)
                for index in indicesToDelete {
                    if index < state.milestones.count {
                        state.milestones.remove(at: index)
                    }
                }
                state.selectedMilestoneIndices.removeAll()
                state.isSelectingMilestones = false
                return .none

            case .saveButtonTapped:
                return .send(._saveMilestones)

            case ._saveMilestones:
                // Ne sauvegarder que si on a un trailId (données déjà en DB)
                guard let trailId = state.trailId else { return .none }
                return .run { [milestones = state.milestones] send in
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
                let currentTrailId = state.trailId ?? 0

                state.milestoneSheet = nil

                if let existingMilestone = sheet.editingMilestone,
                   existingMilestone.id != nil {
                    // Update existing milestone
                    return .concatenate(
                        .send(._updateMilestone(existingMilestone.id!, sheet.selectedType, message, name)),
                        .send(._saveMilestones)
                    )
                } else {
                    // Create new milestone
                    let milestone = Milestone(
                        id: nil,
                        trailId: currentTrailId,
                        pointIndex: sheet.pointIndex,
                        latitude: sheet.latitude,
                        longitude: sheet.longitude,
                        elevation: sheet.elevation,
                        distance: sheet.distance,
                        type: sheet.selectedType,
                        message: message,
                        name: name
                    )
                    return .concatenate(
                        .send(._addMilestone(milestone)),
                        .send(._saveMilestones)
                    )
                }

            case let ._addMilestone(milestone):
                state.milestones.append(milestone)
                state.milestones.sort { $0.distance < $1.distance }
                return .none

            case let ._updateMilestone(id, type, message, name):
                guard let index = state.milestones.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                state.milestones[index].type = type.rawValue
                state.milestones[index].message = message
                state.milestones[index].name = name
                return .none

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
                    TextState("Cette action supprimera définitivement le parcours et tous ses repères.")
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
                // Ne renommer que si on a un trailId
                guard state.trailId != nil else {
                    // Pour un pending trail, juste mettre à jour localement
                    state.trailDetail?.trail.name = newName
                    state.pendingData?.trail.name = newName
                    return .none
                }
                return .send(._updateTrailName(newName))

            case let ._updateTrailName(newName):
                guard let trailId = state.trailId else { return .none }
                return .run { send in
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
                return .send(._deleteTrail)

            case ._deleteTrail:
                guard let trailId = state.trailId else {
                    // Si pas encore sauvé, juste fermer
                    return .run { _ in await dismiss() }
                }
                return .run { _ in
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
