import Foundation
import ComposableArchitecture

@Reducer
struct RootFeature {
    
    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
        @Shared(.appStorage("hasCompletedOnboarding")) var hasCompletedOnboarding = false
    }

    enum Action: Equatable {
        case initiate
        case path(StackAction<Path.State, Path.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .initiate:
                print("[Root] initiate - hasCompletedOnboarding: \(state.hasCompletedOnboarding)")
                print("[Root] initiate - path count before: \(state.path.count)")
                if state.hasCompletedOnboarding {
                    state.path.append(.trailList(TrailListFeature.State()))
                } else {
                    state.path.append(.onboarding(OnboardingFeature.State()))
                }
                print("[Root] initiate - path count after: \(state.path.count)")
                return .none

            case .path(.element(id: _, action: .onboarding(.carouselCompleted))):
                // Sauvegarder que l'onboarding est complété
                state.$hasCompletedOnboarding.withLock { $0 = true }
                // Remplacer l'onboarding par la liste
//                state.path.removeAll()
                state.path.append(.trailList(TrailListFeature.State()))
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            Path()
        }
    }
    
    @Reducer
    struct Path {
        
        @ObservableState
        enum State: Equatable {
            case onboarding(OnboardingFeature.State)
            case trailList(TrailListFeature.State)
        }
        
        enum Action: Equatable {
            case onboarding(OnboardingFeature.Action)
            case trailList(TrailListFeature.Action)
        }
        
        var body: some ReducerOf<Self> {
            Scope(state: \.onboarding, action: \.onboarding) { OnboardingFeature() }
            Scope(state: \.trailList, action: \.trailList) { TrailListFeature() }
        }
    }
}
