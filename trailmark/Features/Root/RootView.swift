import SwiftUI
import ComposableArchitecture

struct RootView: View {
    @Bindable var store: StoreOf<RootStore>

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
            case .editor:
                if let store = store.scope(state: \.editor, action: \.editor) {
                    EditorView(store: store)
                }
            case .run:
                if let store = store.scope(state: \.run, action: \.run) {
                    RunView(store: store)
                }
            case .settings:
                if let store = store.scope(state: \.settings, action: \.settings) {
                    SettingsView(store: store)
                }
            }
        }
    }
}

#Preview("Onboarding") {
    RootView(
        store: Store(initialState: RootStore.State()) {
            RootStore()
        }
    )
}
