import Foundation
import Testing
import ComposableArchitecture
import CoreLocation
@testable import trailmark

@MainActor
struct RunFeatureTests {

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
        distance: Double = 0
    ) -> TrackPoint {
        TrackPoint(
            id: id,
            trailId: trailId,
            index: index,
            latitude: 45.0,
            longitude: 5.0,
            elevation: 100,
            distance: distance
        )
    }

    private static func makeMilestone(
        id: Int64 = 1,
        trailId: Int64 = 1,
        latitude: Double = 45.0,
        longitude: Double = 5.0,
        message: String = "Test milestone"
    ) -> Milestone {
        Milestone(
            id: id,
            trailId: trailId,
            pointIndex: 0,
            latitude: latitude,
            longitude: longitude,
            elevation: 100,
            distance: 0,
            type: .montee,
            message: message,
            name: nil
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

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
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
        }
    }

    // MARK: - _loadTrailDetail

    @Test
    func loadTrailDetail_loadsTrail() async {
        let detail = Self.makeTrailDetail()

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
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
        }
    }

    @Test
    func loadTrailDetail_handlesNilTrail() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 999)) {
            RunFeature()
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

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        }

        await store.send(.trailLoaded(detail)) {
            $0.trailDetail = detail
        }
    }

    // MARK: - startButtonTapped

    @Test
    func startButtonTapped_sendsCheckLocationAuthorization() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedWhenInUse },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: { AsyncStream { $0.finish() } },
                stopTracking: { }
            )
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { },
                configureAudioSession: { }
            )
        }

        store.exhaustivity = .off

        await store.send(.startButtonTapped)
        await store.receive(._checkLocationAuthorization)
    }

    // MARK: - _checkLocationAuthorization

    @Test
    func checkLocationAuthorization_sendsAuthorizationResult() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedWhenInUse },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: { AsyncStream { $0.finish() } },
                stopTracking: { }
            )
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { },
                configureAudioSession: { }
            )
        }

        store.exhaustivity = .off

        await store.send(._checkLocationAuthorization)
        await store.receive(.authorizationResult(CLAuthorizationStatus.authorizedWhenInUse.rawValue))
    }

    @Test
    func checkLocationAuthorization_denied_sendsAuthorizationResult() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .denied },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: { AsyncStream { $0.finish() } },
                stopTracking: { }
            )
        }

        await store.send(._checkLocationAuthorization)
        await store.receive(.authorizationResult(CLAuthorizationStatus.denied.rawValue)) {
            $0.authorizationDenied = true
        }
    }

    // MARK: - authorizationResult

    @Test
    func authorizationResult_authorized_startsRunning() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedWhenInUse },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: { AsyncStream { $0.finish() } },
                stopTracking: { }
            )
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { },
                configureAudioSession: { }
            )
        }

        store.exhaustivity = .off

        await store.send(.authorizationResult(CLAuthorizationStatus.authorizedWhenInUse.rawValue)) {
            $0.isRunning = true
            $0.authorizationDenied = false
        }

        await store.receive(._configureAudioSession)
        await store.receive(._startLocationTracking)
    }

    @Test
    func authorizationResult_authorizedAlways_startsRunning() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedAlways },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: { AsyncStream { $0.finish() } },
                stopTracking: { }
            )
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { },
                configureAudioSession: { }
            )
        }

        store.exhaustivity = .off

        await store.send(.authorizationResult(CLAuthorizationStatus.authorizedAlways.rawValue)) {
            $0.isRunning = true
            $0.authorizationDenied = false
        }

        await store.receive(._configureAudioSession)
        await store.receive(._startLocationTracking)
    }

    @Test
    func authorizationResult_denied_setsAuthorizationDenied() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        }

        await store.send(.authorizationResult(CLAuthorizationStatus.denied.rawValue)) {
            $0.authorizationDenied = true
        }
    }

    @Test
    func authorizationResult_restricted_setsAuthorizationDenied() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        }

        await store.send(.authorizationResult(CLAuthorizationStatus.restricted.rawValue)) {
            $0.authorizationDenied = true
        }
    }

    // MARK: - _configureAudioSession

    @Test
    func configureAudioSession_callsSpeechClient() async {
        var configureAudioSessionCalled = false

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { },
                configureAudioSession: { configureAudioSessionCalled = true }
            )
        }

        await store.send(._configureAudioSession)

        #expect(configureAudioSessionCalled == true)
    }

    // MARK: - _startLocationTracking

    @Test
    func startLocationTracking_receivesLocationUpdates() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedWhenInUse },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: {
                    AsyncStream { continuation in
                        continuation.yield(CLLocation(latitude: 45.0, longitude: 5.0))
                        continuation.finish()
                    }
                },
                stopTracking: { }
            )
        }

        var state = RunFeature.State(trailId: 1)
        state.trailDetail = Self.makeTrailDetail(milestones: [])

        let storeWithDetail = TestStore(initialState: state) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedWhenInUse },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: {
                    AsyncStream { continuation in
                        continuation.yield(CLLocation(latitude: 45.123, longitude: 5.456))
                        continuation.finish()
                    }
                },
                stopTracking: { }
            )
        }

        store.exhaustivity = .off
        storeWithDetail.exhaustivity = .off

        await storeWithDetail.send(._startLocationTracking)
        await storeWithDetail.receive(.locationUpdated(45.123, 5.456))
    }

    // MARK: - locationUpdated

    @Test
    func locationUpdated_sendsInternalActions() async {
        let detail = Self.makeTrailDetail(milestones: [])

        var state = RunFeature.State(trailId: 1)
        state.trailDetail = detail

        let store = TestStore(initialState: state) {
            RunFeature()
        }

        await store.send(.locationUpdated(45.123, 5.456))
        await store.receive(._updateDebugLocation(45.123, 5.456)) {
            $0.currentLatitude = 45.123
            $0.currentLongitude = 5.456
            $0.locationUpdateCount = 1
        }
        await store.receive(._checkMilestoneProximity(45.123, 5.456))
    }

    @Test
    func locationUpdated_withoutTrailDetail_doesNothing() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        }

        await store.send(.locationUpdated(45.123, 5.456))
        // No internal actions should be received
    }

    // MARK: - _updateDebugLocation

    @Test
    func updateDebugLocation_updatesState() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        }

        await store.send(._updateDebugLocation(45.123, 5.456)) {
            $0.currentLatitude = 45.123
            $0.currentLongitude = 5.456
            $0.locationUpdateCount = 1
        }

        await store.send(._updateDebugLocation(45.124, 5.457)) {
            $0.currentLatitude = 45.124
            $0.currentLongitude = 5.457
            $0.locationUpdateCount = 2
        }
    }

    // MARK: - _checkMilestoneProximity

    @Test
    func checkMilestoneProximity_triggersMilestoneWithin30m() async {
        let milestone = Self.makeMilestone(id: 1, latitude: 45.0, longitude: 5.0, message: "Milestone reached!")
        let detail = Self.makeTrailDetail(milestones: [milestone])

        var state = RunFeature.State(trailId: 1)
        state.trailDetail = detail

        let store = TestStore(initialState: state) {
            RunFeature()
        } withDependencies: {
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { },
                configureAudioSession: { }
            )
        }

        store.exhaustivity = .off

        // Location very close to milestone (within 30m)
        await store.send(._checkMilestoneProximity(45.0001, 5.0001)) {
            $0.triggeredMilestoneIds = [1]
        }

        await store.receive(.milestoneTriggered(milestone))
    }

    @Test
    func checkMilestoneProximity_doesNotRetriggerMilestone() async {
        let milestone = Self.makeMilestone(id: 1, latitude: 45.0, longitude: 5.0)
        let detail = Self.makeTrailDetail(milestones: [milestone])

        var state = RunFeature.State(trailId: 1)
        state.trailDetail = detail
        state.triggeredMilestoneIds = [1] // Already triggered

        let store = TestStore(initialState: state) {
            RunFeature()
        }

        // Location close to already-triggered milestone
        await store.send(._checkMilestoneProximity(45.0001, 5.0001))
        // No milestoneTriggered action should be received
    }

    @Test
    func checkMilestoneProximity_updatesClosestMilestoneInfo() async {
        let milestone = Self.makeMilestone(id: 1, latitude: 45.0, longitude: 5.0, message: "Upcoming milestone")
        let detail = Self.makeTrailDetail(milestones: [milestone])

        var state = RunFeature.State(trailId: 1)
        state.trailDetail = detail

        let store = TestStore(initialState: state) {
            RunFeature()
        }

        // Location far from milestone (more than 30m)
        // Distance is approximately 136m
        await store.send(._checkMilestoneProximity(45.001, 5.001)) {
            $0.closestMilestoneDistance = 136
            $0.closestMilestoneMessage = "Upcoming milestone"
        }
    }

    @Test
    func checkMilestoneProximity_withoutTrailDetail_doesNothing() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        }

        await store.send(._checkMilestoneProximity(45.0, 5.0))
        // No state changes
    }

    // MARK: - milestoneTriggered

    @Test
    func milestoneTriggered_setsTTSMessageAndSendsSpeakMessage() async {
        let milestone = Self.makeMilestone(message: "Test message")

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { },
                configureAudioSession: { }
            )
        }

        await store.send(.milestoneTriggered(milestone)) {
            $0.currentTTSMessage = "Test message"
        }

        await store.receive(._speakMessage("Test message"))

        await store.receive(.ttsFinished) {
            $0.currentTTSMessage = nil
        }
    }

    // MARK: - _speakMessage

    @Test
    func speakMessage_callsSpeechClientAndSendsTtsFinished() async {
        var spokenMessage: String?

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.speech = SpeechClient(
                speak: { message in spokenMessage = message },
                stop: { },
                configureAudioSession: { }
            )
        }

        await store.send(._speakMessage("Hello world"))
        await store.receive(.ttsFinished)

        #expect(spokenMessage == "Hello world")
    }

    // MARK: - ttsFinished

    @Test
    func ttsFinished_clearsTTSMessage() async {
        var state = RunFeature.State(trailId: 1)
        state.currentTTSMessage = "Speaking..."

        let store = TestStore(initialState: state) {
            RunFeature()
        }

        await store.send(.ttsFinished) {
            $0.currentTTSMessage = nil
        }
    }

    // MARK: - stopButtonTapped

    @Test
    func stopButtonTapped_sendsInternalStopActions() async {
        var state = RunFeature.State(trailId: 1)
        state.isRunning = true
        state.currentTTSMessage = "Speaking"

        let store = TestStore(initialState: state) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedWhenInUse },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: { AsyncStream { _ in } },
                stopTracking: { }
            )
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { },
                configureAudioSession: { }
            )
            $0.dismiss = DismissEffect { }
        }

        await store.send(.stopButtonTapped) {
            $0.isRunning = false
            $0.currentTTSMessage = nil
        }

        await store.receive(._stopTracking)
        await store.receive(._stopSpeech)
        await store.receive(._dismiss)
    }

    // MARK: - _stopTracking

    @Test
    func stopTracking_callsLocationClient() async {
        var stopTrackingCalled = false

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedWhenInUse },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: { AsyncStream { _ in } },
                stopTracking: { stopTrackingCalled = true }
            )
        }

        await store.send(._stopTracking)

        #expect(stopTrackingCalled == true)
    }

    // MARK: - _stopSpeech

    @Test
    func stopSpeech_callsSpeechClient() async {
        var stopSpeechCalled = false

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { stopSpeechCalled = true },
                configureAudioSession: { }
            )
        }

        await store.send(._stopSpeech)

        #expect(stopSpeechCalled == true)
    }

    // MARK: - _dismiss

    @Test
    func dismiss_callsDismiss() async {
        var dismissCalled = false

        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { dismissCalled = true }
        }

        await store.send(._dismiss)

        #expect(dismissCalled == true)
    }

    // MARK: - backTapped

    @Test
    func backTapped_notRunning_justDismisses() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { }
        }

        await store.send(.backTapped)
        await store.receive(._dismiss)
    }

    @Test
    func backTapped_running_stopsAndDismisses() async {
        var stopTrackingCalled = false
        var stopSpeechCalled = false

        var state = RunFeature.State(trailId: 1)
        state.isRunning = true

        let store = TestStore(initialState: state) {
            RunFeature()
        } withDependencies: {
            $0.location = LocationClient(
                authorizationStatus: { .authorizedWhenInUse },
                requestWhenInUseAuthorization: { },
                delegate: { .finished },
                startTracking: { AsyncStream { _ in } },
                stopTracking: { stopTrackingCalled = true }
            )
            $0.speech = SpeechClient(
                speak: { _ in },
                stop: { stopSpeechCalled = true },
                configureAudioSession: { }
            )
            $0.dismiss = DismissEffect { }
        }

        await store.send(.backTapped)
        await store.receive(._stopTracking)
        await store.receive(._stopSpeech)
        await store.receive(._dismiss)

        #expect(stopTrackingCalled == true)
        #expect(stopSpeechCalled == true)
    }

    // MARK: - toggleDebugView

    @Test
    func toggleDebugView_togglesState() async {
        let store = TestStore(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        }

        await store.send(.toggleDebugView) {
            $0.showDebugView = true
        }

        await store.send(.toggleDebugView) {
            $0.showDebugView = false
        }
    }
}
