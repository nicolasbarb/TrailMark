import SwiftUI
import ComposableArchitecture
import Dependencies
import RevenueCat
import TelemetryDeck

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

        // Configure TelemetryDeck
        if let telemetryAppID = Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String,
           !telemetryAppID.isEmpty,
           telemetryAppID != "your_telemetry_deck_app_id_here" {
            let config = TelemetryDeck.Config(appID: telemetryAppID)
            TelemetryDeck.initialize(config: config)
            TelemetryClient.markConfigured()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: Store(initialState: RootStore.State()) {
                RootStore()
            })
        }
    }
}
