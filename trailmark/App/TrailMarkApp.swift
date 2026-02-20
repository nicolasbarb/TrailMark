import SwiftUI
import ComposableArchitecture
import Dependencies
import RevenueCat

@main
struct TrailMarkApp: App {
    static let store = Store(initialState: RootFeature.State()) {
        RootFeature()
    }

    init() {
        // Bootstrap the database before any dependencies are accessed
        try! prepareDependencies {
            try $0.bootstrapDatabase()
        }

        // Configure RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_QrTpXTemJkitHByxyvcjzRoVAPa")
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: Self.store)
        }
    }
}
