import Foundation
import Testing
import ComposableArchitecture
import Sharing
@testable import trailmark

@MainActor
struct TrailListFeatureTests {

    // MARK: - Test Data

    private static func makeTrail(id: Int64 = 1, name: String = "Test Trail") -> Trail {
        Trail(
            id: id,
            name: name,
            createdAt: Date(),
            distance: 10000,
            dPlus: 500
        )
    }

    private static func makeTrailListItem(id: Int64 = 1, name: String = "Test Trail", milestoneCount: Int = 3) -> TrailListItem {
        TrailListItem(trail: makeTrail(id: id, name: name), milestoneCount: milestoneCount)
    }

    // MARK: - trailsLoaded

    @Test
    func trailsLoaded_updatesState() async {
        let trails = [Self.makeTrailListItem()]

        let store = TestStore(initialState: TrailListFeature.State(isLoading: true)) {
            TrailListFeature()
        }

        await store.send(.trailsLoaded(trails)) {
            $0.isLoading = false
            $0.trails = trails
        }
    }

    // MARK: - premiumStatusChanged

    @Test
    func premiumStatusChanged_updatesPremiumState() async {
        let store = TestStore(initialState: TrailListFeature.State()) {
            TrailListFeature()
        }
        // @Shared state changes don't work well with exhaustive assertions
        store.exhaustivity = .off

        await store.send(.premiumStatusChanged(true))

        #expect(store.state.isPremium == true)
    }

    @Test
    func premiumStatusChanged_toFalse_showsExpiredAlert() async {
        var state = TrailListFeature.State()
        state.$isPremium.withLock { $0 = true }

        let store = TestStore(initialState: state) {
            TrailListFeature()
        }
        // @Shared state changes don't work well with exhaustive assertions
        store.exhaustivity = .off

        await store.send(.premiumStatusChanged(false)) {
            $0.showExpiredAlert = true
        }

        #expect(store.state.isPremium == false)
    }

    // MARK: - addButtonTapped

    @Test
    func addButtonTapped_freeUserWithTrail_opensPaywall() async {
        let trails = [Self.makeTrailListItem()]

        let store = TestStore(initialState: TrailListFeature.State(trails: trails, isPremium: false)) {
            TrailListFeature()
        }

        await store.send(.addButtonTapped) {
            $0.destination = .paywall(PaywallFeature.State())
        }
    }

    @Test
    func addButtonTapped_freeUserNoTrails_opensImport() async {
        let store = TestStore(initialState: TrailListFeature.State(trails: [], isPremium: false)) {
            TrailListFeature()
        }

        await store.send(.addButtonTapped) {
            $0.destination = .importGPX(ImportFeature.State())
        }
    }

    @Test
    func addButtonTapped_premiumUser_opensImport() async {
        let trails = [Self.makeTrailListItem(), Self.makeTrailListItem(id: 2)]

        let store = TestStore(initialState: TrailListFeature.State(trails: trails, isPremium: true)) {
            TrailListFeature()
        }

        await store.send(.addButtonTapped) {
            $0.destination = .importGPX(ImportFeature.State())
        }
    }

    // MARK: - editTrailTapped

    @Test
    func editTrailTapped_opensEditor() async {
        let item = Self.makeTrailListItem(id: 42)

        let store = TestStore(initialState: TrailListFeature.State()) {
            TrailListFeature()
        }

        await store.send(.editTrailTapped(item)) {
            $0.destination = .editor(EditorFeature.State(trailId: 42))
        }
    }

    // MARK: - startTrailTapped

    @Test
    func startTrailTapped_opensRun() async {
        let item = Self.makeTrailListItem(id: 42)

        let store = TestStore(initialState: TrailListFeature.State()) {
            TrailListFeature()
        }

        await store.send(.startTrailTapped(item)) {
            $0.destination = .run(RunFeature.State(trailId: 42))
        }
    }

    // MARK: - deleteTrailTapped

    @Test
    func deleteTrailTapped_deletesAndReloads() async {
        let item = Self.makeTrailListItem(id: 42)
        var deleteCalledWithId: Int64?

        let store = TestStore(initialState: TrailListFeature.State(trails: [item])) {
            TrailListFeature()
        } withDependencies: {
            $0.database = DatabaseClient(
                fetchAllTrails: { [] },
                fetchTrailDetail: { _ in nil },
                insertTrail: { trail, _ in trail },
                deleteTrail: { id in deleteCalledWithId = id },
                saveMilestones: { _, _ in },
                updateTrailName: { _, _ in }
            )
        }

        await store.send(.deleteTrailTapped(item))
        await store.receive(.trailDeleted)
        await store.receive(.trailsLoaded([])) {
            $0.trails = []
        }

        #expect(deleteCalledWithId == 42)
    }

    // MARK: - dismissExpiredAlert

    @Test
    func dismissExpiredAlert_hidesAlert() async {
        let store = TestStore(initialState: TrailListFeature.State(showExpiredAlert: true)) {
            TrailListFeature()
        }

        await store.send(.dismissExpiredAlert) {
            $0.showExpiredAlert = false
        }
    }

    // MARK: - renewTapped

    @Test
    func renewTapped_opensPaywall() async {
        let store = TestStore(initialState: TrailListFeature.State(showExpiredAlert: true)) {
            TrailListFeature()
        }

        await store.send(.renewTapped) {
            $0.showExpiredAlert = false
            $0.destination = .paywall(PaywallFeature.State())
        }
    }

    // MARK: - navigateToEditor

    @Test
    func navigateToEditor_opensEditor() async {
        let store = TestStore(initialState: TrailListFeature.State()) {
            TrailListFeature()
        }

        await store.send(.navigateToEditor(123)) {
            $0.destination = .editor(EditorFeature.State(trailId: 123))
        }
    }

    // MARK: - _incrementVisitCount

    @Test
    func incrementVisitCount_incrementsCounter() async {
        var state = TrailListFeature.State()
        state.$trailListVisitCount.withLock { $0 = 0 }

        let store = TestStore(initialState: state) {
            TrailListFeature()
        }
        // @Shared state changes don't work well with exhaustive assertions
        store.exhaustivity = .off

        await store.send(._incrementVisitCount)

        #expect(store.state.trailListVisitCount == 1)
    }

    @Test
    func incrementVisitCount_incrementsFromExistingValue() async {
        var state = TrailListFeature.State()
        state.$trailListVisitCount.withLock { $0 = 5 }

        let store = TestStore(initialState: state) {
            TrailListFeature()
        }
        store.exhaustivity = .off

        await store.send(._incrementVisitCount)

        #expect(store.state.trailListVisitCount == 6)
    }

    // MARK: - _checkFirstVisitPaywall

    @Test
    func checkFirstVisitPaywall_firstVisit_showsPaywall() async {
        var state = TrailListFeature.State()
        state.$trailListVisitCount.withLock { $0 = 1 }

        let store = TestStore(initialState: state) {
            TrailListFeature()
        }

        await store.send(._checkFirstVisitPaywall) {
            $0.destination = .paywall(PaywallFeature.State())
        }
    }

    @Test
    func checkFirstVisitPaywall_secondVisit_doesNotShowPaywall() async {
        var state = TrailListFeature.State()
        state.$trailListVisitCount.withLock { $0 = 2 }

        let store = TestStore(initialState: state) {
            TrailListFeature()
        }

        await store.send(._checkFirstVisitPaywall)
        // No state change expected
    }

    @Test
    func checkFirstVisitPaywall_zeroVisit_doesNotShowPaywall() async {
        var state = TrailListFeature.State()
        state.$trailListVisitCount.withLock { $0 = 0 }

        let store = TestStore(initialState: state) {
            TrailListFeature()
        }

        await store.send(._checkFirstVisitPaywall)
        // No state change expected
    }

    // MARK: - _loadTrails

    @Test
    func loadTrails_fetchesAndSendsTrailsLoaded() async {
        let expectedTrails = [Self.makeTrailListItem(id: 1), Self.makeTrailListItem(id: 2)]

        let store = TestStore(initialState: TrailListFeature.State()) {
            TrailListFeature()
        } withDependencies: {
            $0.database.fetchAllTrails = { expectedTrails }
        }

        await store.send(._loadTrails)
        await store.receive(.trailsLoaded(expectedTrails)) {
            $0.trails = expectedTrails
            $0.isLoading = false
        }
    }

    @Test
    func loadTrails_emptyDatabase_sendsEmptyArray() async {
        let store = TestStore(initialState: TrailListFeature.State(isLoading: true)) {
            TrailListFeature()
        } withDependencies: {
            $0.database.fetchAllTrails = { [] }
        }

        await store.send(._loadTrails)
        await store.receive(.trailsLoaded([])) {
            $0.isLoading = false
        }
    }

    // MARK: - _startPremiumStream

    @Test
    func startPremiumStream_emitsPremiumStatus() async {
        let store = TestStore(initialState: TrailListFeature.State()) {
            TrailListFeature()
        } withDependencies: {
            $0.subscription.premiumStatusStream = {
                AsyncStream { continuation in
                    continuation.yield(true)
                    continuation.finish()
                }
            }
        }
        // @Shared state changes don't work well with exhaustive assertions
        store.exhaustivity = .off

        await store.send(._startPremiumStream)
        await store.receive(.premiumStatusChanged(true))

        #expect(store.state.isPremium == true)
    }

    @Test
    func startPremiumStream_emitsMultipleUpdates() async {
        let store = TestStore(initialState: TrailListFeature.State()) {
            TrailListFeature()
        } withDependencies: {
            $0.subscription.premiumStatusStream = {
                AsyncStream { continuation in
                    continuation.yield(false)
                    continuation.yield(true)
                    continuation.finish()
                }
            }
        }
        // @Shared state changes don't work well with exhaustive assertions
        store.exhaustivity = .off

        await store.send(._startPremiumStream)
        await store.receive(.premiumStatusChanged(false))
        await store.receive(.premiumStatusChanged(true))

        #expect(store.state.isPremium == true)
    }

    // MARK: - onAppear (integration)

    @Test
    func onAppear_setsLoadingAndDispatchesInternalActions() async {
        let expectedTrails = [Self.makeTrailListItem()]

        let store = TestStore(initialState: TrailListFeature.State()) {
            TrailListFeature()
        } withDependencies: {
            $0.database.fetchAllTrails = { expectedTrails }
            $0.subscription.premiumStatusStream = {
                AsyncStream { continuation in
                    continuation.yield(false)
                    continuation.finish()
                }
            }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        // Verify internal actions are dispatched
        await store.receive(._incrementVisitCount)
        await store.receive(._checkFirstVisitPaywall)
        await store.receive(._loadTrails)
        await store.receive(._startPremiumStream)

        // Verify final state after all effects
        await store.receive(.trailsLoaded(expectedTrails))
        await store.receive(.premiumStatusChanged(false))

        // Assert final state
        #expect(store.state.trailListVisitCount == 1)
        #expect(store.state.destination == .paywall(PaywallFeature.State()))
        #expect(store.state.trails == expectedTrails)
        #expect(store.state.isLoading == false)
    }

    @Test
    func onAppear_secondVisit_doesNotShowPaywall() async {
        var state = TrailListFeature.State()
        state.$trailListVisitCount.withLock { $0 = 1 }

        let store = TestStore(initialState: state) {
            TrailListFeature()
        } withDependencies: {
            $0.database.fetchAllTrails = { [] }
            $0.subscription.premiumStatusStream = {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(._incrementVisitCount)
        await store.receive(._checkFirstVisitPaywall)
        await store.receive(._loadTrails)
        await store.receive(._startPremiumStream)
        await store.receive(.trailsLoaded([]))

        // Assert final state - NO paywall because visitCount is 2
        #expect(store.state.trailListVisitCount == 2)
        #expect(store.state.destination == nil)
        #expect(store.state.isLoading == false)
    }
}
