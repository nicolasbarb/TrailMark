import Foundation
import Testing
import ComposableArchitecture
@testable import trailmark

@MainActor
struct EditorFeatureTests {

    // MARK: - Test Data

    private static func makeTrail(id: Int64 = 1) -> Trail {
        Trail(
            id: id,
            name: "Test Trail",
            createdAt: Date(),
            distance: 10000,
            dPlus: 500
        )
    }

    private static func makeTrackPoint(
        id: Int64 = 1,
        trailId: Int64 = 1,
        index: Int = 0,
        distance: Double = 0,
        elevation: Double = 100
    ) -> TrackPoint {
        TrackPoint(
            id: id,
            trailId: trailId,
            index: index,
            latitude: 45.0,
            longitude: 5.0,
            elevation: elevation,
            distance: distance
        )
    }

    private static func makeMilestone(
        id: Int64? = 1,
        trailId: Int64 = 1,
        pointIndex: Int = 0,
        distance: Double = 0,
        type: MilestoneType = .montee,
        message: String = "Test milestone",
        name: String? = nil
    ) -> Milestone {
        Milestone(
            id: id,
            trailId: trailId,
            pointIndex: pointIndex,
            latitude: 45.0,
            longitude: 5.0,
            elevation: 100,
            distance: distance,
            type: type,
            message: message,
            name: name
        )
    }

    private static func makeTrailDetail(
        trail: Trail? = nil,
        trackPoints: [TrackPoint]? = nil,
        milestones: [Milestone]? = nil
    ) -> TrailDetail {
        TrailDetail(
            trail: trail ?? makeTrail(),
            trackPoints: trackPoints ?? [makeTrackPoint()],
            milestones: milestones ?? [makeMilestone()]
        )
    }

    // MARK: - onAppear

    @Test
    func onAppear_sendsLoadTrailDetail() async {
        let detail = Self.makeTrailDetail()

        let store = TestStore(initialState: EditorFeature.State(trailId: 1)) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in detail },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(.onAppear)
        await store.receive(._loadTrailDetail)
        await store.receive(.trailLoaded(detail)) {
            $0.trailDetail = detail
            $0.milestones = detail.milestones
            $0.originalMilestones = detail.milestones
        }
    }

    // MARK: - _loadTrailDetail

    @Test
    func _loadTrailDetail_loadsTrail() async {
        let detail = Self.makeTrailDetail()

        let store = TestStore(initialState: EditorFeature.State(trailId: 1)) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in detail },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(._loadTrailDetail)
        await store.receive(.trailLoaded(detail)) {
            $0.trailDetail = detail
            $0.milestones = detail.milestones
            $0.originalMilestones = detail.milestones
        }
    }

    @Test
    func _loadTrailDetail_handlesNilTrail() async {
        let store = TestStore(initialState: EditorFeature.State(trailId: 999)) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(._loadTrailDetail)
        // No trailLoaded action should be received
    }

    // MARK: - trailLoaded

    @Test
    func trailLoaded_setsState() async {
        let detail = Self.makeTrailDetail()

        let store = TestStore(initialState: EditorFeature.State(trailId: 1)) {
            EditorFeature()
        }

        await store.send(.trailLoaded(detail)) {
            $0.trailDetail = detail
            $0.milestones = detail.milestones
            $0.originalMilestones = detail.milestones
        }
    }

    // MARK: - tabSelected

    @Test
    func tabSelected_changesTab() async {
        let store = TestStore(initialState: EditorFeature.State(trailId: 1)) {
            EditorFeature()
        }

        await store.send(.tabSelected(.milestones)) {
            $0.selectedTab = .milestones
        }

        await store.send(.tabSelected(.map)) {
            $0.selectedTab = .map
        }
    }

    // MARK: - cursorMoved

    @Test
    func cursorMoved_updatesCursor() async {
        let store = TestStore(initialState: EditorFeature.State(trailId: 1)) {
            EditorFeature()
        }

        await store.send(.cursorMoved(10)) {
            $0.cursorPointIndex = 10
        }

        await store.send(.cursorMoved(nil)) {
            $0.cursorPointIndex = nil
        }
    }

    // MARK: - _removeMilestoneAt

    @Test
    func _removeMilestoneAt_removesMilestone() async {
        let milestone1 = Self.makeMilestone(id: 1, distance: 100)
        let milestone2 = Self.makeMilestone(id: 2, distance: 200)

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone1, milestone2]
        state.originalMilestones = [milestone1, milestone2]

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(._removeMilestoneAt(0)) {
            $0.milestones = [milestone2]
        }
    }

    @Test
    func _removeMilestoneAt_invalidIndex_doesNothing() async {
        let milestone1 = Self.makeMilestone(id: 1, distance: 100)

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone1]

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(._removeMilestoneAt(5))
        // State should remain unchanged
    }

    // MARK: - _removeSelectedMilestones

    @Test
    func _removeSelectedMilestones_removesSelected() async {
        let milestone1 = Self.makeMilestone(id: 1, distance: 100)
        let milestone2 = Self.makeMilestone(id: 2, distance: 200)
        let milestone3 = Self.makeMilestone(id: 3, distance: 300)

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone1, milestone2, milestone3]
        state.isSelectingMilestones = true
        state.selectedMilestoneIndices = [0, 2]

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(._removeSelectedMilestones) {
            $0.milestones = [milestone2]
            $0.selectedMilestoneIndices = []
            $0.isSelectingMilestones = false
        }
    }

    // MARK: - _saveMilestones

    @Test
    func _saveMilestones_savesMilestones() async {
        let milestone = Self.makeMilestone()
        var savedMilestones: [Milestone]?
        var savedTrailId: Int64?

        var state = EditorFeature.State(trailId: 42)
        state.milestones = [milestone]
        state.originalMilestones = []

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { trailId, milestones in
                    savedTrailId = trailId
                    savedMilestones = milestones
                },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(._saveMilestones)
        await store.receive(.savingCompleted) {
            $0.originalMilestones = [milestone]
        }

        #expect(savedTrailId == 42)
        #expect(savedMilestones?.count == 1)
    }

    // MARK: - _addMilestone

    @Test
    func _addMilestone_appendsAndSorts() async {
        let existingMilestone = Self.makeMilestone(id: 1, distance: 200)
        let newMilestone = Self.makeMilestone(id: nil, distance: 100)

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [existingMilestone]

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(._addMilestone(newMilestone)) {
            // Should be sorted by distance
            $0.milestones = [newMilestone, existingMilestone]
        }
    }

    // MARK: - _updateMilestone

    @Test
    func _updateMilestone_updatesExistingMilestone() async {
        let milestone = Self.makeMilestone(id: 1, type: .montee, message: "Old message", name: nil)

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone]

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(._updateMilestone(1, .descente, "New message", "Col")) {
            $0.milestones[0].type = MilestoneType.descente.rawValue
            $0.milestones[0].message = "New message"
            $0.milestones[0].name = "Col"
        }
    }

    @Test
    func _updateMilestone_invalidId_doesNothing() async {
        let milestone = Self.makeMilestone(id: 1)

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone]

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(._updateMilestone(999, .plat, "Test", nil))
        // State should remain unchanged
    }

    // MARK: - _updateTrailName

    @Test
    func _updateTrailName_updatesNameInDatabase() async {
        var updatedTrailId: Int64?
        var updatedName: String?

        let detail = Self.makeTrailDetail()
        var state = EditorFeature.State(trailId: 42)
        state.trailDetail = detail

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { id, name in
                    updatedTrailId = id
                    updatedName = name
                }
            )
        }

        await store.send(._updateTrailName("New Name"))
        await store.receive(.trailNameUpdated("New Name")) {
            $0.trailDetail?.trail.name = "New Name"
        }

        #expect(updatedTrailId == 42)
        #expect(updatedName == "New Name")
    }

    // MARK: - _deleteTrail

    @Test
    func _deleteTrail_deletesAndDismisses() async {
        var deletedTrailId: Int64?

        let store = TestStore(initialState: EditorFeature.State(trailId: 42)) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { id in deletedTrailId = id },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
            $0.dismiss = DismissEffect { }
        }

        await store.send(._deleteTrail)

        #expect(deletedTrailId == 42)
    }

    // MARK: - deleteMilestone (orchestration)

    @Test
    func deleteMilestone_sendsRemoveAndSave() async {
        let milestone1 = Self.makeMilestone(id: 1, distance: 100)
        let milestone2 = Self.makeMilestone(id: 2, distance: 200)

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone1, milestone2]
        state.originalMilestones = [milestone1, milestone2]

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(.deleteMilestone(0))
        await store.receive(._removeMilestoneAt(0)) {
            $0.milestones = [milestone2]
        }
        await store.receive(._saveMilestones)
        await store.receive(.savingCompleted) {
            $0.originalMilestones = [milestone2]
        }
    }

    // MARK: - deleteSelectedMilestones (orchestration)

    @Test
    func deleteSelectedMilestones_sendsRemoveSelectedAndSave() async {
        let milestone1 = Self.makeMilestone(id: 1, distance: 100)
        let milestone2 = Self.makeMilestone(id: 2, distance: 200)
        let milestone3 = Self.makeMilestone(id: 3, distance: 300)

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone1, milestone2, milestone3]
        state.originalMilestones = [milestone1, milestone2, milestone3]
        state.isSelectingMilestones = true
        state.selectedMilestoneIndices = [0, 2]

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(.deleteSelectedMilestones)
        await store.receive(._removeSelectedMilestones) {
            $0.milestones = [milestone2]
            $0.selectedMilestoneIndices = []
            $0.isSelectingMilestones = false
        }
        await store.receive(._saveMilestones)
        await store.receive(.savingCompleted) {
            $0.originalMilestones = [milestone2]
        }
    }

    // MARK: - saveButtonTapped (orchestration)

    @Test
    func saveButtonTapped_sendsSaveMilestones() async {
        let milestone = Self.makeMilestone()

        var state = EditorFeature.State(trailId: 42)
        state.milestones = [milestone]
        state.originalMilestones = []

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(.saveButtonTapped)
        await store.receive(._saveMilestones)
        await store.receive(.savingCompleted) {
            $0.originalMilestones = [milestone]
        }
    }

    // MARK: - toggleSelectionMode

    @Test
    func toggleSelectionMode_togglesAndClearsSelection() async {
        var state = EditorFeature.State(trailId: 1)
        state.selectedMilestoneIndices = [0, 1]

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        // Enable selection mode
        await store.send(.toggleSelectionMode) {
            $0.isSelectingMilestones = true
        }

        // Disable selection mode - clears selection
        await store.send(.toggleSelectionMode) {
            $0.isSelectingMilestones = false
            $0.selectedMilestoneIndices = []
        }
    }

    // MARK: - toggleMilestoneSelection

    @Test
    func toggleMilestoneSelection_togglesIndex() async {
        let store = TestStore(initialState: EditorFeature.State(trailId: 1)) {
            EditorFeature()
        }

        await store.send(.toggleMilestoneSelection(0)) {
            $0.selectedMilestoneIndices = [0]
        }

        await store.send(.toggleMilestoneSelection(1)) {
            $0.selectedMilestoneIndices = [0, 1]
        }

        await store.send(.toggleMilestoneSelection(0)) {
            $0.selectedMilestoneIndices = [1]
        }
    }

    // MARK: - savingCompleted

    @Test
    func savingCompleted_updatesOriginalMilestones() async {
        let milestone = Self.makeMilestone()

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone]
        state.originalMilestones = []

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(.savingCompleted) {
            $0.originalMilestones = [milestone]
        }
    }

    // MARK: - backTapped

    @Test
    func backTapped_callsDismiss() async {
        let store = TestStore(initialState: EditorFeature.State(trailId: 1)) {
            EditorFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { }
        }

        await store.send(.backTapped)
    }

    // MARK: - renameButtonTapped

    @Test
    func renameButtonTapped_startsRenaming() async {
        let detail = Self.makeTrailDetail()
        var state = EditorFeature.State(trailId: 1)
        state.trailDetail = detail

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(.renameButtonTapped) {
            $0.editedTrailName = "Test Trail"
            $0.isRenamingTrail = true
        }
    }

    // MARK: - renameCancelled

    @Test
    func renameCancelled_stopsRenaming() async {
        var state = EditorFeature.State(trailId: 1)
        state.isRenamingTrail = true
        state.editedTrailName = "New Name"

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(.renameCancelled) {
            $0.isRenamingTrail = false
        }
    }

    // MARK: - renameConfirmed (orchestration)

    @Test
    func renameConfirmed_sendsUpdateTrailName() async {
        let detail = Self.makeTrailDetail()
        var state = EditorFeature.State(trailId: 42)
        state.trailDetail = detail
        state.isRenamingTrail = true
        state.editedTrailName = "New Name"

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(.renameConfirmed) {
            $0.isRenamingTrail = false
        }

        await store.receive(._updateTrailName("New Name"))

        await store.receive(.trailNameUpdated("New Name")) {
            $0.trailDetail?.trail.name = "New Name"
        }
    }

    @Test
    func renameConfirmed_emptyName_doesNotUpdate() async {
        var updateCalled = false

        var state = EditorFeature.State(trailId: 1)
        state.isRenamingTrail = true
        state.editedTrailName = "   "

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in updateCalled = true }
            )
        }

        await store.send(.renameConfirmed) {
            $0.isRenamingTrail = false
        }

        #expect(updateCalled == false)
    }

    // MARK: - deleteTrailButtonTapped

    @Test
    func deleteTrailButtonTapped_showsAlert() async {
        let store = TestStore(initialState: EditorFeature.State(trailId: 1)) {
            EditorFeature()
        }

        await store.send(.deleteTrailButtonTapped) {
            $0.alert = AlertState {
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
        }
    }

    // MARK: - alert confirmDelete (orchestration)

    @Test
    func alertConfirmDelete_sendsDeleteTrail() async {
        var deletedTrailId: Int64?

        // Create state with the alert already showing
        var state = EditorFeature.State(trailId: 42)
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
            TextState("Cette action supprimera definitivement le parcours et tous ses reperes.")
        }

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { id in deletedTrailId = id },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
            $0.dismiss = DismissEffect { }
        }

        await store.send(.alert(.presented(.confirmDelete))) {
            $0.alert = nil
        }

        await store.receive(._deleteTrail)

        #expect(deletedTrailId == 42)
    }

    // MARK: - hasMilestoneChanges

    @Test
    func hasMilestoneChanges_detectsChanges() async {
        let milestone = Self.makeMilestone()

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone]
        state.originalMilestones = []

        #expect(state.hasMilestoneChanges == true)

        state.originalMilestones = [milestone]
        #expect(state.hasMilestoneChanges == false)
    }

    // MARK: - profileTapped

    @Test
    func profileTapped_opensMilestoneSheet() async {
        let trackPoints = [
            Self.makeTrackPoint(id: 1, index: 0, distance: 0, elevation: 100),
            Self.makeTrackPoint(id: 2, index: 1, distance: 100, elevation: 100),
        ]
        let detail = Self.makeTrailDetail(trackPoints: trackPoints, milestones: [])

        var state = EditorFeature.State(trailId: 1)
        state.trailDetail = detail

        let store = TestStore(initialState: state) {
            EditorFeature()
        }
        store.exhaustivity = .off

        await store.send(.profileTapped(0))

        // MilestoneSheetFeature.State has a random UUID, so we verify after send
        #expect(store.state.milestoneSheet != nil)
        #expect(store.state.milestoneSheet?.editingMilestone == nil)
        #expect(store.state.milestoneSheet?.pointIndex == 0)
        #expect(store.state.milestoneSheet?.latitude == 45.0)
        #expect(store.state.milestoneSheet?.longitude == 5.0)
        #expect(store.state.milestoneSheet?.elevation == 100)
        #expect(store.state.milestoneSheet?.distance == 0)
        #expect(store.state.milestoneSheet?.selectedType == .plat)
        #expect(store.state.milestoneSheet?.message == "")
        #expect(store.state.milestoneSheet?.name == "")
    }

    @Test
    func profileTapped_invalidIndex_doesNothing() async {
        let detail = Self.makeTrailDetail(trackPoints: [Self.makeTrackPoint()], milestones: [])

        var state = EditorFeature.State(trailId: 1)
        state.trailDetail = detail

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(.profileTapped(100))
        // No state change expected
    }

    // MARK: - editMilestone

    @Test
    func editMilestone_opensMilestoneSheetWithData() async {
        let milestone = Self.makeMilestone(
            id: 1,
            pointIndex: 5,
            distance: 500,
            type: .descente,
            message: "Descente technique",
            name: "Col de la Croix"
        )

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [milestone]

        let store = TestStore(initialState: state) {
            EditorFeature()
        }
        store.exhaustivity = .off

        await store.send(.editMilestone(milestone))

        // MilestoneSheetFeature.State has a random UUID, so we verify after send
        #expect(store.state.milestoneSheet != nil)
        #expect(store.state.milestoneSheet?.editingMilestone == milestone)
        #expect(store.state.milestoneSheet?.pointIndex == 5)
        #expect(store.state.milestoneSheet?.latitude == 45.0)
        #expect(store.state.milestoneSheet?.longitude == 5.0)
        #expect(store.state.milestoneSheet?.elevation == 100)
        #expect(store.state.milestoneSheet?.distance == 500)
        #expect(store.state.milestoneSheet?.selectedType == .descente)
        #expect(store.state.milestoneSheet?.message == "Descente technique")
        #expect(store.state.milestoneSheet?.name == "Col de la Croix")
    }

    // MARK: - milestoneSheet saveButtonTapped (new milestone)

    @Test
    func milestoneSheetSave_newMilestone_addsAndSaves() async {
        var state = EditorFeature.State(trailId: 1)
        state.milestones = []
        state.originalMilestones = []
        state.milestoneSheet = MilestoneSheetFeature.State(
            editingMilestone: nil,
            pointIndex: 10,
            latitude: 45.5,
            longitude: 5.5,
            elevation: 200,
            distance: 1000,
            selectedType: .montee,
            message: "Debut montee",
            name: "Col"
        )

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        let expectedMilestone = Milestone(
            id: nil,
            trailId: 1,
            pointIndex: 10,
            latitude: 45.5,
            longitude: 5.5,
            elevation: 200,
            distance: 1000,
            type: .montee,
            message: "Debut montee",
            name: "Col"
        )

        await store.send(.milestoneSheet(.presented(.saveButtonTapped))) {
            $0.milestoneSheet = nil
        }

        await store.receive(._addMilestone(expectedMilestone)) {
            $0.milestones = [expectedMilestone]
        }

        await store.receive(._saveMilestones)

        await store.receive(.savingCompleted) {
            $0.originalMilestones = [expectedMilestone]
        }
    }

    // MARK: - milestoneSheet saveButtonTapped (edit milestone)

    @Test
    func milestoneSheetSave_editMilestone_updatesAndSaves() async {
        let existingMilestone = Self.makeMilestone(
            id: 1,
            pointIndex: 10,
            distance: 1000,
            type: .montee,
            message: "Old message"
        )

        var state = EditorFeature.State(trailId: 1)
        state.milestones = [existingMilestone]
        state.originalMilestones = [existingMilestone]
        state.milestoneSheet = MilestoneSheetFeature.State(
            editingMilestone: existingMilestone,
            pointIndex: 10,
            latitude: 45.0,
            longitude: 5.0,
            elevation: 100,
            distance: 1000,
            selectedType: .descente,
            message: "New message",
            name: "Summit"
        )

        let store = TestStore(initialState: state) {
            EditorFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(.milestoneSheet(.presented(.saveButtonTapped))) {
            $0.milestoneSheet = nil
        }

        await store.receive(._updateMilestone(1, .descente, "New message", "Summit")) {
            $0.milestones[0].type = MilestoneType.descente.rawValue
            $0.milestones[0].message = "New message"
            $0.milestones[0].name = "Summit"
        }

        await store.receive(._saveMilestones)

        await store.receive(.savingCompleted) {
            $0.originalMilestones = $0.milestones
        }
    }

    // MARK: - milestoneSheet dismissTapped

    @Test
    func milestoneSheetDismiss_closesSheet() async {
        var state = EditorFeature.State(trailId: 1)
        state.milestoneSheet = MilestoneSheetFeature.State(
            editingMilestone: nil,
            pointIndex: 0,
            latitude: 45.0,
            longitude: 5.0,
            elevation: 100,
            distance: 0,
            selectedType: .plat,
            message: "",
            name: ""
        )

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(.milestoneSheet(.presented(.dismissTapped))) {
            $0.milestoneSheet = nil
        }
    }

    // MARK: - trailNameUpdated

    @Test
    func trailNameUpdated_updatesTrailDetail() async {
        let detail = Self.makeTrailDetail()
        var state = EditorFeature.State(trailId: 1)
        state.trailDetail = detail

        let store = TestStore(initialState: state) {
            EditorFeature()
        }

        await store.send(.trailNameUpdated("Updated Trail Name")) {
            $0.trailDetail?.trail.name = "Updated Trail Name"
        }
    }
}
