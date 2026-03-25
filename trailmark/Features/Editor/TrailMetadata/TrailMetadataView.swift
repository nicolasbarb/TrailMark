import SwiftUI
import ComposableArchitecture

struct TrailMetadataView: View {
    @Bindable var store: StoreOf<TrailMetadataStore>

    var body: some View {
        // This view is empty — it only provides modifiers
        Color.clear
            .frame(width: 0, height: 0)
            .alert($store.scope(state: \.alert, action: \.alert))
            .alert(
                "editor.renameAlert.title",
                isPresented: Binding(
                    get: { store.isRenamingTrail },
                    set: { if !$0 { store.send(.renameCancelled) } }
                )
            ) {
                TextField("editor.renameAlert.placeholder", text: $store.editedTrailName)
                Button("common.cancel", role: .cancel) {
                    Haptic.light.trigger()
                    store.send(.renameCancelled)
                }
                Button("common.rename") {
                    Haptic.medium.trigger()
                    store.send(.renameConfirmed)
                }
                .keyboardShortcut(.defaultAction)
            }
    }
}

// MARK: - Preview

#Preview("Trail Metadata Toolbar") {
    NavigationStack {
        Text("Editor Content")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Renommer le fichier", systemImage: "square.and.pencil") { }
                        Button("Supprimer le fichier", systemImage: "trash", role: .destructive) { }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .overlay {
                TrailMetadataView(
                    store: Store(
                        initialState: TrailMetadataStore.State()
                    ) {
                        TrailMetadataStore()
                    }
                )
            }
    }
}