import Foundation
import CoreLocation
import Dependencies

// MARK: - LocationClient

struct LocationClient: Sendable {
    var authorizationStatus: @Sendable () -> CLAuthorizationStatus
    var requestWhenInUseAuthorization: @Sendable () -> Void
    var delegate: @Sendable () -> AsyncStream<DelegateEvent>
    var startTracking: @Sendable () -> AsyncStream<CLLocation>
    var stopTracking: @Sendable () -> Void

    enum DelegateEvent: Equatable {
        case didChangeAuthorization(CLAuthorizationStatus)
    }
}

// MARK: - DependencyKey

extension LocationClient: DependencyKey {
    static var liveValue: LocationClient {
        let locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true

        return LocationClient(
            authorizationStatus: {
                locationManager.authorizationStatus
            },
            requestWhenInUseAuthorization: {
                locationManager.requestWhenInUseAuthorization()
            },
            delegate: {
                // Use buffering to ensure events aren't lost before iteration starts
                AsyncStream(bufferingPolicy: .bufferingNewest(10)) { continuation in
                    let delegate = Delegate(continuation: continuation)
                    locationManager.delegate = delegate
                    continuation.onTermination = { _ in
                        _ = delegate // Keep delegate alive
                    }
                }
            },
            startTracking: {
                AsyncStream { continuation in
                    let delegate = TrackingDelegate(
                        continuation: continuation,
                        locationManager: locationManager
                    )
                    locationManager.delegate = delegate
                    locationManager.startUpdatingLocation()
                    continuation.onTermination = { _ in
                        locationManager.stopUpdatingLocation()
                        _ = delegate
                    }
                }
            },
            stopTracking: {
                locationManager.stopUpdatingLocation()
            }
        )
    }

    static var testValue: LocationClient {
        LocationClient(
            authorizationStatus: { .authorizedWhenInUse },
            requestWhenInUseAuthorization: { },
            delegate: { .finished },
            startTracking: { AsyncStream { _ in } },
            stopTracking: { }
        )
    }
}

extension DependencyValues {
    var location: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

// MARK: - Delegate for Authorization

extension LocationClient {
    private class Delegate: NSObject, CLLocationManagerDelegate {
        let continuation: AsyncStream<LocationClient.DelegateEvent>.Continuation

        init(continuation: AsyncStream<LocationClient.DelegateEvent>.Continuation) {
            self.continuation = continuation
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            print("[LocationClient] Authorization changed: \(manager.authorizationStatus.rawValue)")
            continuation.yield(.didChangeAuthorization(manager.authorizationStatus))
        }
    }
}

// MARK: - Delegate for Tracking

extension LocationClient {
    private class TrackingDelegate: NSObject, CLLocationManagerDelegate {
        let continuation: AsyncStream<CLLocation>.Continuation
        let locationManager: CLLocationManager

        init(continuation: AsyncStream<CLLocation>.Continuation, locationManager: CLLocationManager) {
            self.continuation = continuation
            self.locationManager = locationManager
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            for location in locations {
                continuation.yield(location)
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("[LocationClient] Location error: \(error.localizedDescription)")
        }
    }
}
