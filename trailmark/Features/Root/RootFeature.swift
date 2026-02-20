import Foundation
import ComposableArchitecture

@Reducer
struct RootFeature {
    @ObservableState
    struct State: Equatable {
        var hasCompletedOnboarding: Bool
        var onboarding: OnboardingFeature.State?
        var trailList: TrailListFeature.State?

        init() {
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            if hasCompletedOnboarding {
                self.trailList = TrailListFeature.State()
            } else {
                self.onboarding = OnboardingFeature.State()
            }
        }
    }

    enum Action: Equatable {
        case onboarding(OnboardingFeature.Action)
        case trailList(TrailListFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onboarding(.completeOnboarding):
                // Sauvegarder que l'onboarding est complété
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                state.hasCompletedOnboarding = true
                state.onboarding = nil
                state.trailList = TrailListFeature.State()
                return .none

            case .onboarding:
                return .none

            case .trailList:
                return .none
            }
        }
        .ifLet(\.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        .ifLet(\.trailList, action: \.trailList) {
            TrailListFeature()
        }
    }
}
