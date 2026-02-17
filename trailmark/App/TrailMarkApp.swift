import SwiftUI
import ComposableArchitecture
import Dependencies

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
    }

    var body: some Scene {
        WindowGroup {
            TrailListView(store: Self.store)
        }
    }
}
