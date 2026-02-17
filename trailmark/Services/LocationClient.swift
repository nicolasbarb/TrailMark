import Foundation
import CoreLocation
import Dependencies

// MARK: - LocationClient

struct LocationClient: Sendable {
    var requestAuthorization: @Sendable () async -> CLAuthorizationStatus
    var startTracking: @Sendable () -> AsyncStream<CLLocation>
    var stopTracking: @Sendable () -> Void
    var authorizationStatus: @Sendable () -> CLAuthorizationStatus
}

// MARK: - DependencyKey

extension LocationClient: DependencyKey {
    static var liveValue: LocationClient {
        let manager = LocationManager()

        return LocationClient(
            requestAuthorization: {
                await manager.requestAuthorization()
            },
            startTracking: {
                manager.startTracking()
            },
            stopTracking: {
                manager.stopTracking()
            },
            authorizationStatus: {
                manager.currentAuthorizationStatus()
            }
        )
    }

    static var testValue: LocationClient {
        LocationClient(
            requestAuthorization: { .authorizedWhenInUse },
            startTracking: { AsyncStream { _ in } },
            stopTracking: { },
            authorizationStatus: { .authorizedWhenInUse }
        )
    }
}

extension DependencyValues {
    var location: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

// MARK: - LocationManager

private final class LocationManager: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    nonisolated(unsafe) private let clManager = CLLocationManager()
    private let lock = NSLock()
    nonisolated(unsafe) private var _continuation: AsyncStream<CLLocation>.Continuation?
    nonisolated(unsafe) private var _authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    nonisolated private var continuation: AsyncStream<CLLocation>.Continuation? {
        get { lock.withLock { _continuation } }
        set { lock.withLock { _continuation = newValue } }
    }

    nonisolated private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>? {
        get { lock.withLock { _authorizationContinuation } }
        set { lock.withLock { _authorizationContinuation = newValue } }
    }

    nonisolated func currentAuthorizationStatus() -> CLAuthorizationStatus {
        clManager.authorizationStatus
    }

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.distanceFilter = 10
        clManager.allowsBackgroundLocationUpdates = true
        clManager.pausesLocationUpdatesAutomatically = false
        clManager.showsBackgroundLocationIndicator = true
    }

    func requestAuthorization() async -> CLAuthorizationStatus {
        let status = clManager.authorizationStatus

        switch status {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.authorizationContinuation = continuation
                self.clManager.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse:
            // Escalate to Always
            return await withCheckedContinuation { continuation in
                self.authorizationContinuation = continuation
                self.clManager.requestAlwaysAuthorization()
            }
        default:
            return status
        }
    }

    nonisolated func startTracking() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.clManager.stopUpdatingLocation()
            }
            self.clManager.startUpdatingLocation()
        }
    }

    nonisolated func stopTracking() {
        clManager.stopUpdatingLocation()
        continuation?.finish()
        continuation = nil
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            continuation?.yield(location)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let cont = authorizationContinuation {
            cont.resume(returning: manager.authorizationStatus)
            authorizationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Log error but continue tracking
        print("Location error: \(error.localizedDescription)")
    }
}
