import Foundation
import StoreKit
import Dependencies

// MARK: - StoreKitClient

struct StoreKitClient: Sendable {
    var requestReview: @Sendable () async -> Void
}

// MARK: - DependencyKey

extension StoreKitClient: DependencyKey {
    @MainActor
    static let liveValue = StoreKitClient(
        requestReview: {
            guard let windowScene = await UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else { return }
            try? await AppStore.requestReview(in: windowScene)
        }
    )

    static let testValue = StoreKitClient(
        requestReview: {}
    )
}

// MARK: - DependencyValues

extension DependencyValues {
    var storeKit: StoreKitClient {
        get { self[StoreKitClient.self] }
        set { self[StoreKitClient.self] = newValue }
    }
}
