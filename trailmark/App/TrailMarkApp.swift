import SwiftUI
import ComposableArchitecture
import Dependencies
import RevenueCat

@main
struct TrailMarkApp: App {
    static let store = Store(initialState: TrailListFeature.State()) {
        TrailListFeature()
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
            TrailListView(store: Self.store)
        }
    }
}
