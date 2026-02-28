import Foundation
import Testing
import ComposableArchitecture
@testable import trailmark

@MainActor
struct ImportFeatureTests {

    // MARK: - Test Data

    private static func makeTrail(id: Int64? = nil) -> Trail {
        Trail(
            id: id,
            name: "Test Trail",
            createdAt: Date(),
            distance: 10000,
            dPlus: 500
        )
    }

    private static func makeTrackPoints(count: Int = 100) -> [TrackPoint] {
        (0..<count).map { index in
            TrackPoint(
                id: nil,
                trailId: 0,
                index: index,
                latitude: 45.0 + Double(index) * 0.001,
                longitude: 6.0 + Double(index) * 0.001,
                elevation: 1000 + Double(index) * 5,
                distance: Double(index) * 100
            )
        }
    }

    private static func makeMilestones(count: Int = 3) -> [Milestone] {
        (0..<count).map { index -> Milestone in
            let type: MilestoneType
            switch index {
            case 0: type = .montee
            case 1: type = .descente
            default: type = .plat
            }
            return Milestone(
                id: nil,
                trailId: 0,
                pointIndex: index * 30,
                latitude: 45.0 + Double(index) * 0.03,
                longitude: 6.0 + Double(index) * 0.03,
                elevation: 1000 + Double(index) * 150,
                distance: Double(index) * 3000,
                type: type,
                message: "Milestone \(index + 1)",
                name: nil
            )
        }
    }

    // MARK: - Upload Phase

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

    @Test
    func filePickerDismissed_hidesFilePicker() async {
        let store = TestStore(initialState: ImportFeature.State(isShowingFilePicker: true)) {
            ImportFeature()
        }

        await store.send(.filePickerDismissed) {
            $0.isShowingFilePicker = false
        }
    }

    @Test
    func fileSelected_transitionsToAnalyzing() async {
        let store = TestStore(initialState: ImportFeature.State()) {
            ImportFeature()
        }

        await store.send(.fileSelected("/path/to/file.gpx")) {
            $0.phase = .analyzing
            $0.error = nil
        }

        // Skip the import failed action since we can't parse a non-existent file
        await store.skipReceivedActions()
    }

    // MARK: - Analysis Phase

    @Test
    func analysisCompleted_transitionsToResult() async {
        let trail = Self.makeTrail()
        let trackPoints = Self.makeTrackPoints()
        let milestones = Self.makeMilestones()

        let store = TestStore(initialState: ImportFeature.State(phase: .analyzing)) {
            ImportFeature()
        }

        await store.send(.analysisCompleted(trail, trackPoints, milestones)) {
            $0.phase = .result
            $0.parsedTrail = trail
            $0.parsedTrackPoints = trackPoints
            $0.detectedMilestones = milestones
        }
    }

    @Test
    func analysisCompleted_withNoMilestones() async {
        let trail = Self.makeTrail()
        let trackPoints = Self.makeTrackPoints()

        let store = TestStore(initialState: ImportFeature.State(phase: .analyzing)) {
            ImportFeature()
        }

        await store.send(.analysisCompleted(trail, trackPoints, [])) {
            $0.phase = .result
            $0.parsedTrail = trail
            $0.parsedTrackPoints = trackPoints
            $0.detectedMilestones = []
        }
    }

    @Test
    func importFailed_returnsToUpload() async {
        let store = TestStore(initialState: ImportFeature.State(phase: .analyzing)) {
            ImportFeature()
        }

        await store.send(.importFailed("Failed to parse GPX")) {
            $0.phase = .upload
            $0.error = "Failed to parse GPX"
        }
    }

    // MARK: - Result Phase

    @Test
    func continueWithMilestonesTapped_sendsImportCompleted() async {
        let trail = Self.makeTrail()
        let trackPoints = Self.makeTrackPoints()
        let milestones = Self.makeMilestones()

        let store = TestStore(
            initialState: ImportFeature.State(
                phase: .result,
                parsedTrail: trail,
                parsedTrackPoints: trackPoints,
                detectedMilestones: milestones
            )
        ) {
            ImportFeature()
        }

        let expectedPendingData = PendingTrailData(
            trail: trail,
            trackPoints: trackPoints,
            detectedMilestones: milestones
        )

        await store.send(.continueWithMilestonesTapped)
        await store.receive(.importCompleted(expectedPendingData))
    }

    @Test
    func skipTapped_sendsImportCompletedWithoutMilestones() async {
        let trail = Self.makeTrail()
        let trackPoints = Self.makeTrackPoints()
        let milestones = Self.makeMilestones()

        let store = TestStore(
            initialState: ImportFeature.State(
                phase: .result,
                parsedTrail: trail,
                parsedTrackPoints: trackPoints,
                detectedMilestones: milestones
            )
        ) {
            ImportFeature()
        }

        let expectedPendingData = PendingTrailData(
            trail: trail,
            trackPoints: trackPoints,
            detectedMilestones: [] // No milestones
        )

        await store.send(.skipTapped)
        await store.receive(.importCompleted(expectedPendingData))
    }

    @Test
    func skipTapped_withNoMilestones_sendsImportCompleted() async {
        let trail = Self.makeTrail()
        let trackPoints = Self.makeTrackPoints()

        let store = TestStore(
            initialState: ImportFeature.State(
                phase: .result,
                parsedTrail: trail,
                parsedTrackPoints: trackPoints,
                detectedMilestones: []
            )
        ) {
            ImportFeature()
        }

        let expectedPendingData = PendingTrailData(
            trail: trail,
            trackPoints: trackPoints,
            detectedMilestones: []
        )

        await store.send(.skipTapped)
        await store.receive(.importCompleted(expectedPendingData))
    }

    @Test
    func dismissTapped_callsDismiss() async {
        let store = TestStore(initialState: ImportFeature.State()) {
            ImportFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { }
        }

        await store.send(.dismissTapped)
    }

    // MARK: - Paywall

    @Test
    func unlockTapped_presentsPaywall() async {
        let trail = Self.makeTrail()
        let trackPoints = Self.makeTrackPoints()
        let milestones = Self.makeMilestones()

        let store = TestStore(
            initialState: ImportFeature.State(
                phase: .result,
                parsedTrail: trail,
                parsedTrackPoints: trackPoints,
                detectedMilestones: milestones
            )
        ) {
            ImportFeature()
        }

        await store.send(.unlockTapped) {
            $0.paywall = PaywallFeature.State()
        }
    }

    @Test
    func paywallPurchaseCompleted_setsIsPremiumAndStaysOnResult() async {
        let trail = Self.makeTrail()
        let trackPoints = Self.makeTrackPoints()
        let milestones = Self.makeMilestones()

        let store = TestStore(
            initialState: ImportFeature.State(
                phase: .result,
                parsedTrail: trail,
                parsedTrackPoints: trackPoints,
                detectedMilestones: milestones,
                paywall: PaywallFeature.State()
            )
        ) {
            ImportFeature()
        }
        // @Shared state changes don't work well with exhaustive assertions
        store.exhaustivity = .off

        await store.send(.paywall(.presented(.purchaseCompleted))) {
            $0.paywall = nil
        }
        // Should stay on result phase, not auto-continue
        #expect(store.state.phase == .result)
        #expect(store.state.isPremium == true)
    }

    @Test
    func paywallRestoreCompleted_setsIsPremiumAndStaysOnResult() async {
        let trail = Self.makeTrail()
        let trackPoints = Self.makeTrackPoints()
        let milestones = Self.makeMilestones()

        let store = TestStore(
            initialState: ImportFeature.State(
                phase: .result,
                parsedTrail: trail,
                parsedTrackPoints: trackPoints,
                detectedMilestones: milestones,
                paywall: PaywallFeature.State()
            )
        ) {
            ImportFeature()
        }
        // @Shared state changes don't work well with exhaustive assertions
        store.exhaustivity = .off

        await store.send(.paywall(.presented(.restoreCompleted))) {
            $0.paywall = nil
        }
        // Should stay on result phase, not auto-continue
        #expect(store.state.phase == .result)
        #expect(store.state.isPremium == true)
    }

    @Test
    func paywallDismiss_closesPaywall() async {
        let store = TestStore(
            initialState: ImportFeature.State(
                phase: .result,
                paywall: PaywallFeature.State()
            )
        ) {
            ImportFeature()
        }

        await store.send(.paywall(.dismiss)) {
            $0.paywall = nil
        }
    }
}
