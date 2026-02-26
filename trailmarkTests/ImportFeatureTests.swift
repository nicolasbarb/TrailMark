import Foundation
import Testing
import ComposableArchitecture
@testable import trailmark

@MainActor
struct ImportFeatureTests {

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

    // MARK: - uploadZoneTapped

    @Test
    func uploadZoneTapped_showsFilePicker() async {
        let store = TestStore(initialState: ImportFeature.State()) {
            ImportFeature()
        }

        await store.send(.uploadZoneTapped) {
            $0.isShowingFilePicker = true
            $0.error = nil
        }
    }

    @Test
    func uploadZoneTapped_clearsError() async {
        let store = TestStore(initialState: ImportFeature.State(error: "Previous error")) {
            ImportFeature()
        }

        await store.send(.uploadZoneTapped) {
            $0.isShowingFilePicker = true
            $0.error = nil
        }
    }

    // MARK: - filePickerDismissed

    @Test
    func filePickerDismissed_hidesFilePicker() async {
        let store = TestStore(initialState: ImportFeature.State(isShowingFilePicker: true)) {
            ImportFeature()
        }

        await store.send(.filePickerDismissed) {
            $0.isShowingFilePicker = false
        }
    }

    // MARK: - fileSelected

    @Test
    func fileSelected_setsImporting() async {
        let store = TestStore(initialState: ImportFeature.State()) {
            ImportFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in
                    Trail(
                        id: 1,
                        name: trail.name,
                        createdAtTimestamp: trail.createdAt,
                        distance: trail.distance,
                        dPlus: trail.dPlus
                    )
                },
                deleteTrail: { _ in },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        // Test the immediate state change - the parsing will fail (no real file)
        // so we expect importFailed to be received
        await store.send(.fileSelected("/path/to/file.gpx")) {
            $0.isImporting = true
            $0.error = nil
        }

        // Skip the import failed action since we can't parse a non-existent file
        await store.skipReceivedActions()
    }

    // MARK: - importCompleted

    @Test
    func importCompleted_stopsImporting() async {
        let trail = Self.makeTrail()
        let store = TestStore(initialState: ImportFeature.State(isImporting: true)) {
            ImportFeature()
        }

        await store.send(.importCompleted(trail)) {
            $0.isImporting = false
        }
    }

    // MARK: - importFailed

    @Test
    func importFailed_setsError() async {
        let store = TestStore(initialState: ImportFeature.State(isImporting: true)) {
            ImportFeature()
        }

        await store.send(.importFailed("Failed to parse GPX")) {
            $0.isImporting = false
            $0.error = "Failed to parse GPX"
        }
    }

    @Test
    func importFailed_stopsImporting() async {
        let store = TestStore(initialState: ImportFeature.State(isImporting: true)) {
            ImportFeature()
        }

        await store.send(.importFailed("Error message")) {
            $0.isImporting = false
            $0.error = "Error message"
        }
    }

    // MARK: - dismissTapped

    @Test
    func dismissTapped_callsDismiss() async {
        let store = TestStore(initialState: ImportFeature.State()) {
            ImportFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { }
        }

        await store.send(.dismissTapped)
    }
}
