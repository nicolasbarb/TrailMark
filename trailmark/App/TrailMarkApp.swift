import SwiftUI
import ComposableArchitecture
import Dependencies
import RevenueCat

@main
struct TrailMarkApp: App {
    init() {
        // Bootstrap the database before any dependencies are accessed
        try! prepareDependencies {
            try $0.bootstrapDatabase()
        }

        // Configure RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_NaxLylZgwBhBsgEWrJUJPJQRvFv")
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: Store(initialState: RootFeature.State()) {
                RootFeature()
            })
        }
    }
}
