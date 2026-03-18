import SwiftUI
import ComposableArchitecture

struct TrailMetadataToolbar: View {
    @Bindable var store: StoreOf<TrailMetadataFeature>

    var body: some View {
        // This view is empty — it only provides modifiers
        Color.clear
            .frame(width: 0, height: 0)
            .alert($store.scope(state: \.alert, action: \.alert))
            .alert(
                "Renommer le parcours",
                isPresented: Binding(
                    get: { store.isRenamingTrail },
                    set: { if !$0 { store.send(.renameCancelled) } }
                )
            ) {
                TextField("Nom du parcours", text: $store.editedTrailName)
                Button("Annuler", role: .cancel) {
                    Haptic.light.trigger()
                    store.send(.renameCancelled)
                }
                Button("Renommer") {
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
                TrailMetadataToolbar(
                    store: Store(
                        initialState: TrailMetadataFeature.State()
                    ) {
                        TrailMetadataFeature()
                    }
                )
            }
    }
}