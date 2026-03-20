import Foundation
import ComposableArchitecture
import CoreLocation

// MARK: - Pending Trail Data (données non sauvegardées)

struct PendingTrailData: Equatable, Sendable {
    var trail: Trail
    var trackPoints: [TrackPoint]
    var detectedMilestones: [Milestone]
}

// MARK: - Editor Feature (Parent Coordinator)

@Reducer
struct EditorStore {
    @ObservableState
    struct State: Equatable, Sendable {
        // Mode: soit trailId (existant), soit pendingData (nouveau)
        var trailId: Int64?
        var pendingData: PendingTrailData?

        var trailDetail: TrailDetail?
        var milestones: [Milestone] = []
        var originalMilestones: [Milestone] = []
        var isSavingInBackground = false
        @Shared(.inMemory("isPremium")) var isPremium = false

        // Child features
        var elevationProfile = ElevationProfileStore.State()
        var trailMetadata = TrailMetadataStore.State()
        var segmentPanel = SegmentPanelStore.State()

        // Presentations
        @Presents var milestoneSheet: MilestoneSheetStore.State?
        @Presents var paywall: PaywallStore.State?

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

    enum Action: Equatable {
        case onAppear
        case trailLoaded(TrailDetail)
        case backgroundSaveCompleted(Trail, [Milestone])
        case backgroundSaveFailed
        case savingCompleted([Milestone])

        // Child features
        case elevationProfile(ElevationProfileStore.Action)
        case trailMetadata(TrailMetadataStore.Action)
        case segmentPanel(SegmentPanelStore.Action)

        // Presentations
        case milestoneSheet(PresentationAction<MilestoneSheetStore.Action>)
        case paywall(PresentationAction<PaywallStore.Action>)

        // Internal
        case _loadTrailDetail
        case _loadPendingData
        case _saveMilestones
        case _addMilestone(Milestone)
        case _updateMilestone(Int64, MilestoneType, String, String?)
        case _removeMilestoneAt(Int)
    }

    @Dependency(\.database) var database
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Scope(state: \.elevationProfile, action: \.elevationProfile) {
            ElevationProfileStore()
        }
        Scope(state: \.trailMetadata, action: \.trailMetadata) {
            TrailMetadataStore()
        }
        Scope(state: \.segmentPanel, action: \.segmentPanel) {
            SegmentPanelStore()
        }

        EditorAnalyticsReducer()

        Reduce { state, action in
            switch action {

            // MARK: - Lifecycle

            case .onAppear:
                if state.trailId != nil {
                    return .send(._loadTrailDetail)
                }
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

                let detail = TrailDetail(
                    trail: pending.trail,
                    trackPoints: pending.trackPoints,
                    milestones: pending.detectedMilestones
                )
                state.trailDetail = detail
                state.milestones = pending.detectedMilestones
                state.originalMilestones = pending.detectedMilestones
                state.isSavingInBackground = true
                // Sync child state
                state.trailMetadata.trailName = pending.trail.name

                return .run { [pending] send in
                    do {
                        let savedTrail = try await database.insertTrail(pending.trail, pending.trackPoints)
                        if let trailId = savedTrail.id, !pending.detectedMilestones.isEmpty {
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
                            let savedMs = try await database.saveMilestones(trailId, milestonesWithTrailId)
                            await send(.backgroundSaveCompleted(savedTrail, savedMs))
                        } else {
                            await send(.backgroundSaveCompleted(savedTrail, []))
                        }
                    } catch {
                        await send(.backgroundSaveFailed)
                    }
                }

            case let .trailLoaded(detail):
                state.trailDetail = detail
                state.milestones = detail.milestones
                state.originalMilestones = detail.milestones
                // Sync child state
                state.trailMetadata.trailId = state.trailId
                state.trailMetadata.trailName = detail.trail.name
                return .none

            case let .backgroundSaveCompleted(savedTrail, savedMilestones):
                state.isSavingInBackground = false
                state.trailId = savedTrail.id
                state.pendingData = nil
                state.trailDetail?.trail = savedTrail
                if !savedMilestones.isEmpty {
                    state.milestones = savedMilestones
                    state.originalMilestones = savedMilestones
                }
                // Sync child state
                state.trailMetadata.trailId = savedTrail.id
                state.trailMetadata.trailName = savedTrail.name
                return .none

            case .backgroundSaveFailed:
                state.isSavingInBackground = false
                return .none

            // MARK: - Milestone CRUD

            case ._saveMilestones:
                guard let trailId = state.trailId else { return .none }
                return .run { [milestones = state.milestones] send in
                    let saved = try await database.saveMilestones(trailId, milestones)
                    await send(.savingCompleted(saved))
                }

            case let .savingCompleted(savedMilestones):
                state.milestones = savedMilestones
                state.originalMilestones = savedMilestones
                return .none

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

            case let ._removeMilestoneAt(index):
                guard index < state.milestones.count else { return .none }
                state.milestones.remove(at: index)
                return .none

            // MARK: - ElevationProfile Delegates

            case let .elevationProfile(.delegate(.profileTapped(pointIndex))):
                guard let detail = state.trailDetail,
                      pointIndex < detail.trackPoints.count else { return .none }

                if !state.isPremium && state.milestones.count >= 10 {
                    state.paywall = PaywallStore.State()
                    return .none
                }

                let point = detail.trackPoints[pointIndex]
                let detectedType = Self.detectMilestoneType(at: pointIndex, trackPoints: detail.trackPoints)
                let terrainTypes = ElevationProfileAnalyzer.classify(trackPoints: detail.trackPoints)
                let lookaheadStats = ElevationProfileAnalyzer.computeLookaheadStats(
                    from: pointIndex,
                    trackPoints: detail.trackPoints,
                    terrainTypes: terrainTypes
                )
                let autoMessage = AnnouncementBuilder.build(
                    type: detectedType,
                    name: nil,
                    lookaheadStats: lookaheadStats
                )

                state.milestoneSheet = MilestoneSheetStore.State(
                    editingMilestone: nil,
                    pointIndex: pointIndex,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    elevation: point.elevation,
                    distance: point.distance,
                    selectedType: detectedType,
                    personalMessage: "",
                    name: "",
                    autoMessage: autoMessage
                )
                return .none

            case let .elevationProfile(.delegate(.milestoneTapped(milestone))):
                return .send(.elevationProfile(.delegate(.editMilestone(milestone))))

            case let .elevationProfile(.delegate(.editMilestone(milestone))):
                state.milestoneSheet = buildMilestoneSheetState(for: milestone, trailDetail: state.trailDetail)
                return .none

            case let .elevationProfile(.scrollPositionChanged(index)):
                // Sync scroll position to segment panel
                state.segmentPanel.currentScrollIndex = index
                return .none

            case .elevationProfile:
                return .none

            // MARK: - TrailMetadata Delegates

            case .trailMetadata(.delegate(.trailDeleted)):
                return .run { _ in await dismiss() }

            case let .trailMetadata(.delegate(.trailRenamed(newName))):
                state.trailDetail?.trail.name = newName
                state.pendingData?.trail.name = newName
                return .none

            case .trailMetadata:
                return .none

            // MARK: - SegmentPanel Delegates

            case .segmentPanel(.delegate(.addMilestoneTapped)):
                let index = state.elevationProfile.scrolledPointIndex
                return .send(.elevationProfile(.delegate(.profileTapped(index))))

            case let .segmentPanel(.delegate(.goToMilestone(milestone))):
                return .none // View handles scrolling

            case let .segmentPanel(.delegate(.editMilestone(milestone))):
                // Open milestone sheet inside the list sheet (nested)
                let detail = state.trailDetail
                state.segmentPanel.milestoneList?.milestoneSheet = buildMilestoneSheetState(for: milestone, trailDetail: detail)
                return .none

            // MARK: - MilestoneSheet from List (nested sheet)

            case .segmentPanel(.milestoneList(.presented(.milestoneSheet(.presented(.typeSelected(let type)))))):
                if let sheet = state.segmentPanel.milestoneList?.milestoneSheet, let detail = state.trailDetail {
                    state.segmentPanel.milestoneList?.milestoneSheet?.autoMessage = recomputeAutoMessage(
                        type: type, name: sheet.edit.name, pointIndex: sheet.pointIndex, detail: detail
                    )
                }
                return .none

            case .segmentPanel(.milestoneList(.presented(.milestoneSheet(.presented(.saveButtonTapped))))):
                guard let sheet = state.segmentPanel.milestoneList?.milestoneSheet else { return .none }
                state.segmentPanel.milestoneList?.milestoneSheet = nil
                return handleMilestoneSave(sheet: sheet, state: &state)

            case .segmentPanel(.milestoneList(.presented(.milestoneSheet(.presented(.deleteButtonTapped))))):
                guard let sheet = state.segmentPanel.milestoneList?.milestoneSheet else { return .none }
                state.segmentPanel.milestoneList?.milestoneSheet = nil
                return handleMilestoneDelete(sheet: sheet, state: &state)

            case .segmentPanel(.milestoneList(.presented(.milestoneSheet(.presented(.dismissTapped))))):
                state.segmentPanel.milestoneList?.milestoneSheet = nil
                return .none

            case .segmentPanel:
                return .none

            // MARK: - MilestoneSheet (direct from profile tap)

            case .milestoneSheet(.presented(.typeSelected(let type))):
                if let sheet = state.milestoneSheet, let detail = state.trailDetail {
                    state.milestoneSheet?.autoMessage = recomputeAutoMessage(
                        type: type, name: sheet.edit.name, pointIndex: sheet.pointIndex, detail: detail
                    )
                }
                return .none

            case .milestoneSheet(.presented(.saveButtonTapped)):
                guard let sheet = state.milestoneSheet else { return .none }
                state.milestoneSheet = nil
                return handleMilestoneSave(sheet: sheet, state: &state)

            case .milestoneSheet(.presented(.deleteButtonTapped)):
                guard let sheet = state.milestoneSheet else { return .none }
                state.milestoneSheet = nil
                return handleMilestoneDelete(sheet: sheet, state: &state)

            case .milestoneSheet(.presented(.dismissTapped)):
                state.milestoneSheet = nil
                return .none

            case .milestoneSheet:
                return .none

            // MARK: - Paywall

            case .paywall(.presented(.purchaseCompleted)),
                 .paywall(.presented(.restoreCompleted)):
                state.$isPremium.withLock { $0 = true }
                return .none

            case .paywall(.dismiss):
                state.paywall = nil
                return .none

            case .paywall:
                return .none
            }
        }
        .ifLet(\.$milestoneSheet, action: \.milestoneSheet) {
            MilestoneSheetStore()
        }
        .ifLet(\.$paywall, action: \.paywall) {
            PaywallStore()
        }
    }

    // MARK: - Helpers

    static func detectMilestoneType(at index: Int, trackPoints: [TrackPoint]) -> MilestoneType {
        let lookAhead = 20
        let futureIndex = min(index + lookAhead, trackPoints.count - 1)
        guard futureIndex > index else { return .plat }
        let currentElevation = trackPoints[index].elevation
        let futureElevation = trackPoints[futureIndex].elevation
        let delta = futureElevation - currentElevation
        if delta > 10 { return .montee }
        else if delta < -10 { return .descente }
        else { return .plat }
    }

    /// Build MilestoneSheetStore.State for editing an existing milestone
    private func buildMilestoneSheetState(for milestone: Milestone, trailDetail: TrailDetail?) -> MilestoneSheetStore.State {
        return MilestoneSheetStore.State(
            editingMilestone: milestone,
            pointIndex: milestone.pointIndex,
            latitude: milestone.latitude,
            longitude: milestone.longitude,
            elevation: milestone.elevation,
            distance: milestone.distance,
            selectedType: milestone.milestoneType,
            personalMessage: milestone.message,
            name: milestone.name ?? ""
        )
    }

    /// Recompute autoMessage when type changes
    private func recomputeAutoMessage(type: MilestoneType, name: String, pointIndex: Int, detail: TrailDetail) -> String? {
        let terrainTypes = ElevationProfileAnalyzer.classify(trackPoints: detail.trackPoints)
        let lookaheadStats = ElevationProfileAnalyzer.computeLookaheadStats(
            from: pointIndex,
            trackPoints: detail.trackPoints,
            terrainTypes: terrainTypes
        )
        return AnnouncementBuilder.build(
            type: type,
            name: name.isEmpty ? nil : name,
            lookaheadStats: lookaheadStats
        )
    }

    /// Handle save from any MilestoneSheetStore
    private func handleMilestoneSave(sheet: MilestoneSheetStore.State, state: inout State) -> Effect<Action> {
        let edit = sheet.edit
        let fullMessage = edit.personalMessage.isEmpty
            ? edit.selectedType.label
            : edit.personalMessage
        let name: String? = edit.name.isEmpty ? nil : edit.name
        let currentTrailId = state.trailId ?? 0

        if let existingMilestone = sheet.editingMilestone,
           let milestoneId = existingMilestone.id {
            return .concatenate(
                .send(._updateMilestone(milestoneId, edit.selectedType, fullMessage, name)),
                .send(._saveMilestones)
            )
        } else {
            let milestone = Milestone(
                id: nil,
                trailId: currentTrailId,
                pointIndex: sheet.pointIndex,
                latitude: sheet.latitude,
                longitude: sheet.longitude,
                elevation: sheet.elevation,
                distance: sheet.distance,
                type: edit.selectedType,
                message: fullMessage,
                name: name
            )
            return .concatenate(
                .send(._addMilestone(milestone)),
                .send(._saveMilestones)
            )
        }
    }

    /// Handle delete from any MilestoneSheetStore
    private func handleMilestoneDelete(sheet: MilestoneSheetStore.State, state: inout State) -> Effect<Action> {
        guard let editingMilestone = sheet.editingMilestone,
              let milestoneId = editingMilestone.id,
              let index = state.milestones.firstIndex(where: { $0.id == milestoneId }) else {
            return .none
        }
        return .concatenate(
            .send(._removeMilestoneAt(index)),
            .send(._saveMilestones)
        )
    }
}
