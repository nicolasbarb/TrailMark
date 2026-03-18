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
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              !apiKey.isEmpty,
              apiKey != "your_revenuecat_api_key_here"
        else {
            fatalError("Missing RevenueCatAPIKey — copy Secrets.xcconfig.template to Secrets.xcconfig and fill in your key")
        }
        Purchases.configure(withAPIKey: apiKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: Store(initialState: RootStore.State()) {
                RootStore()
            })
        }
    }
}
