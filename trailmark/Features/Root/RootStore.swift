import Foundation
import ComposableArchitecture

@Reducer
struct RootStore {
    
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
                if state.hasCompletedOnboarding {
                    state.path.append(.trailList(TrailListStore.State()))
                } else {
                    state.path.append(.onboarding(OnboardingStore.State()))
                }
                return .none

            case .path(.element(id: _, action: .onboarding(.carouselCompleted))):
                state.$hasCompletedOnboarding.withLock { $0 = true }
                state.path.append(.trailList(TrailListStore.State()))
                return .none

            case let .path(.element(id: _, action: .trailList(.delegate(.navigateToEditor(trailId))))):
                state.path.append(.editor(EditorStore.State(trailId: trailId)))
                return .none

            case let .path(.element(id: _, action: .trailList(.delegate(.navigateToEditorWithPendingData(pendingData))))):
                state.path.append(.editor(EditorStore.State(pendingData: pendingData)))
                return .none

            case let .path(.element(id: _, action: .trailList(.delegate(.navigateToRun(trailId))))):
                state.path.append(.run(RunStore.State(trailId: trailId)))
                return .none

            case .path(.element(id: _, action: .trailList(.delegate(.navigateToSettings)))):
                state.path.append(.settings(SettingsStore.State()))
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
            case onboarding(OnboardingStore.State)
            case trailList(TrailListStore.State)
            case editor(EditorStore.State)
            case run(RunStore.State)
            case settings(SettingsStore.State)
        }

        enum Action: Equatable {
            case onboarding(OnboardingStore.Action)
            case trailList(TrailListStore.Action)
            case editor(EditorStore.Action)
            case run(RunStore.Action)
            case settings(SettingsStore.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: \.onboarding, action: \.onboarding) { OnboardingStore() }
            Scope(state: \.trailList, action: \.trailList) { TrailListStore() }
            Scope(state: \.editor, action: \.editor) { EditorStore() }
            Scope(state: \.run, action: \.run) { RunStore() }
            Scope(state: \.settings, action: \.settings) { SettingsStore() }
        }
    }
}
