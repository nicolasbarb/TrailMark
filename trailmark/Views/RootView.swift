import SwiftUI
import ComposableArchitecture

struct RootView: View {
    @Bindable var store: StoreOf<RootFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            Color.clear
                .onAppear {
                    store.send(.initiate)
                }
        } destination: { store in
            switch store.state {
            case .onboarding:
                if let store = store.scope(state: \.onboarding, action: \.onboarding) {
                    OnboardingView(store: store)
                        .navigationBarBackButtonHidden()
                }
            case .trailList:
                if let store = store.scope(state: \.trailList, action: \.trailList) {
                    TrailListView(store: store)
                        .navigationBarBackButtonHidden()
                }
            }
        }
    }
}

#Preview("Onboarding") {
    RootView(
        store: Store(initialState: RootFeature.State()) {
            RootFeature()
        }
    )
}
