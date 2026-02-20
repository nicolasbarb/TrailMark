import SwiftUI
import ComposableArchitecture

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        Group {
            if let onboardingStore = store.scope(state: \.onboarding, action: \.onboarding) {
                OnboardingView(store: onboardingStore)
            } else if let trailListStore = store.scope(state: \.trailList, action: \.trailList) {
                TrailListView(store: trailListStore)
            }
        }
    }
}

#Preview("Onboarding") {
    RootView(
        store: Store(initialState: {
            var state = RootFeature.State()
            state.hasCompletedOnboarding = false
            state.onboarding = OnboardingFeature.State()
            state.trailList = nil
            return state
        }()) {
            RootFeature()
        }
    )
}

#Preview("Trail List") {
    RootView(
        store: Store(initialState: {
            var state = RootFeature.State()
            state.hasCompletedOnboarding = true
            state.onboarding = nil
            state.trailList = TrailListFeature.State()
            return state
        }()) {
            RootFeature()
        }
    )
}
