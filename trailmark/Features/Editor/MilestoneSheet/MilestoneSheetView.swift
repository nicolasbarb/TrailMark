import SwiftUI
import ComposableArchitecture

struct MilestoneSheetView: View {
    @Bindable var store: StoreOf<MilestoneSheetStore>
    @State private var selectedDetent: PresentationDetent

    init(store: StoreOf<MilestoneSheetStore>) {
        self.store = store
        self._selectedDetent = State(initialValue: store.effectiveStep == .announcementPreview ? .fraction(0.35) : .large)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [TM.accent.opacity(0.08), TM.bgSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    switch store.effectiveStep {
                    case .announcementPreview:
                        if let announcementStore = store.scope(state: \.announcementPreview, action: \.announcementPreview) {
                            AnnouncementPreviewView(store: announcementStore)
                        }

                    case .editing:
                        MilestoneEditView(store: store.scope(state: \.edit, action: \.edit))
                    }
                }
            }
            .presentationDetents([.fraction(0.35), .large], selection: $selectedDetent)
            .presentationBackground(store.effectiveStep == .announcementPreview ? .clear : TM.bgCard)
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(store.effectiveStep == .editing)
            .onChange(of: store.effectiveStep) { _, newStep in
                withAnimation(.spring(duration: 0.4)) {
                    selectedDetent = newStep == .announcementPreview ? .fraction(0.35) : .large
                }
            }
            .onChange(of: selectedDetent) { _, newDetent in
                let expected: PresentationDetent = store.effectiveStep == .announcementPreview ? .fraction(0.35) : .large
                if newDetent != expected {
                    selectedDetent = expected
                }
            }
            .toolbar(store.effectiveStep == .editing ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark", role: .cancel) {
                        Haptic.light.trigger()
                        store.send(.dismissTapped)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(store.isEditing ? "Modifier" : "Nouveau repère")
                            .font(.headline)
                        PointStatsView(distanceMeters: store.distance, altitudeMeters: store.elevation)
                    }
                }

                if store.isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Supprimer", systemImage: "trash", role: .destructive) {
                            Haptic.warning.trigger()
                            store.send(.deleteButtonTapped)
                        }
                        .tint(TM.danger)
                    }

                    ToolbarSpacer(.fixed, placement: .confirmationAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider", systemImage: "checkmark") {
                        Haptic.success.trigger()
                        store.send(.saveButtonTapped)
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(
                item: $store.scope(state: \.paywall, action: \.paywall)
            ) { paywallStore in
                PaywallContainerView(store: paywallStore)
            }
        }
    }
}

// MARK: - Previews

private let previewAutoMessage = "Montée. 1 virgule 8 kilomètres à 12 pourcent. 215 mètres de dénivelé positif."

#Preview("AnnouncementPreview — PRO") {
    Color.clear.sheet(isPresented: .constant(true)) {
        MilestoneSheetView(
            store: Store(
                initialState: MilestoneSheetStore.State(
                    pointIndex: 50, latitude: 45.0641, longitude: 6.4078,
                    elevation: 2350, distance: 3500, selectedType: .montee,
                    personalMessage: "", name: "",
                    autoMessage: previewAutoMessage
                )
            ) { MilestoneSheetStore() }
        )
    }
}

#Preview("AnnouncementPreview — Gratuit") {
    Color.clear.sheet(isPresented: .constant(true)) {
        MilestoneSheetView(
            store: Store(
                initialState: MilestoneSheetStore.State(
                    pointIndex: 50, latitude: 45.0641, longitude: 6.4078,
                    elevation: 2350, distance: 3500, selectedType: .montee,
                    personalMessage: "", name: "",
                    autoMessage: previewAutoMessage
                )
            ) { MilestoneSheetStore() }
        )
    }
}

#Preview("Editing — PRO") {
    Color.clear.sheet(isPresented: .constant(true)) {
        MilestoneSheetView(
            store: Store(
                initialState: MilestoneSheetStore.State(
                    pointIndex: 50, latitude: 45.0641, longitude: 6.4078,
                    elevation: 2350, distance: 3500, selectedType: .montee,
                    personalMessage: previewAutoMessage, name: "",
                    autoMessage: previewAutoMessage,
                    useAutoAnnouncement: true,
                    step: .editing
                )
            ) { MilestoneSheetStore() }
        )
    }
}

#Preview("Editing — Gratuit") {
    Color.clear.sheet(isPresented: .constant(true)) {
        MilestoneSheetView(
            store: Store(
                initialState: MilestoneSheetStore.State(
                    pointIndex: 50, latitude: 45.0641, longitude: 6.4078,
                    elevation: 2350, distance: 3500, selectedType: .montee,
                    personalMessage: "", name: "",
                    autoMessage: previewAutoMessage,
                    step: .editing
                )
            ) { MilestoneSheetStore() }
        )
    }
}
