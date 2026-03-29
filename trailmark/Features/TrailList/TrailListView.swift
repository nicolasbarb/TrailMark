import SwiftUI
import ComposableArchitecture

struct TrailListView: View {
    @Bindable var store: StoreOf<TrailListStore>
    
    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()
            
            if store.trails.isEmpty && !store.isLoading {
                emptyState
            } else {
                trailList
            }
        }
        .toolbar {
            
            if store.isPremium {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptic.light.trigger()
                        store.send(.proBadgeTapped)
                    } label: {
                        ProBadge()
                    }
                }
            }
            
            ToolbarSpacer(.fixed, placement: .primaryAction)
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptic.medium.trigger()
                    store.send(.addButtonTapped)
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptic.light.trigger()
                    store.send(.settingsTapped)
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .toolbarRole(.editor)
        .navigationTitle(Text("trailList.title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(
            item: $store.scope(state: \.destination?.importGPX, action: \.destination.importGPX)
        ) { importStore in
            ImportView(store: importStore)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.editor, action: \.destination.editor)
        ) { editorStore in
            EditorView(store: editorStore)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.run, action: \.destination.run)
        ) { runStore in
            RunView(store: runStore)
        }
        .navigationDestination(
            item: $store.scope(state: \.destination?.settings, action: \.destination.settings)
        ) { settingsStore in
            SettingsView(store: settingsStore)
        }
        .fullScreenCover(
            item: $store.scope(state: \.destination?.paywall, action: \.destination.paywall)
        ) { paywallStore in
            PaywallContainerView(store: paywallStore)
        }
        .fullScreenCover(
            item: $store.scope(state: \.destination?.subscriptionInfo, action: \.destination.subscriptionInfo)
        ) { subscriptionInfoStore in
            SubscriptionInfoView(store: subscriptionInfoStore)
        }
        .alert(
            "trailList.expiredAlert.title",
            isPresented: Binding(
                get: { store.showExpiredAlert },
                set: { if !$0 { store.send(.dismissExpiredAlert) } }
            )
        ) {
            Button("trailList.expiredAlert.renewButton") {
                Haptic.medium.trigger()
                store.send(.renewTapped)
            }
            Button("common.later", role: .cancel) {
                Haptic.light.trigger()
                store.send(.dismissExpiredAlert)
            }
        } message: {
            Text("trailList.expiredAlert.message")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Text("🏔️")
                .font(.system(size: 40))
            
            Text("trailList.emptyState.title")
                .font(.headline)
                .foregroundStyle(TM.textSecondary)

            Text("trailList.emptyState.description")
                .font(.caption)
                .foregroundStyle(TM.textMuted)
                .multilineTextAlignment(.center)
            
            Button {
                Haptic.medium.trigger()
                store.send(.addButtonTapped)
            } label: {
                Text("trailList.importButton")
            }
            .primaryButton(size: .large, width: .fitted, shape: .capsule)
            
            Spacer()
        }
    }
    
    // MARK: - Trail List
    
    private var trailList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(store.trails.enumerated()), id: \.element.id) { index, item in
                    let isLocked = !store.isPremium && index > 0
                    let isExpanded = store.expandedTrailId == item.trail.id
                    TrailCard(
                        item: item,
                        isLocked: isLocked,
                        isExpanded: isExpanded,
                        onTap: {
                            Haptic.light.trigger()
                            store.send(.trailCardTapped(item))
                        },
                        onEdit: {
                            Haptic.light.trigger()
                            store.send(.editTrailTapped(item))
                        },
                        onStart: {
                            Haptic.heavy.trigger()
                            store.send(.startTrailTapped(item))
                        },
                        onUnlock: {
                            Haptic.medium.trigger()
                            store.send(.trailCardTapped(item))
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Trail Card

private struct TrailCard: View {
    let item: TrailListItem
    let isLocked: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onStart: () -> Void
    let onUnlock: () -> Void

    private var trail: Trail { item.trail }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: name + date
            HStack {
                Text(trail.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TM.textPrimary)

                Spacer()

                Text(trail.createdAtDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(TM.textMuted)
            }

            // Elevation profile
            if !item.trackPoints.isEmpty {
                ElevationProfilePreview(
                    trackPoints: item.trackPoints,
                    milestones: item.milestones
                )
                .frame(height: 60)
                .clipShape(.rect(cornerRadius: 8))
            }

            // Stats row
            HStack(spacing: 0) {
                statItem(
                    value: String(format: "%.1f", trail.distance / 1000),
                    unit: "km"
                )

                Text("·")
                    .font(.caption2)
                    .foregroundStyle(TM.textMuted)
                    .padding(.horizontal, 6)

                statItem(
                    value: "\(trail.dPlus)",
                    unit: String(localized: "trailList.elevationGain")
                )

                Text("·")
                    .font(.caption2)
                    .foregroundStyle(TM.textMuted)
                    .padding(.horizontal, 6)

                statItem(
                    value: "\(item.milestoneCount)",
                    unit: String(localized: "trailList.milestones")
                )

                Spacer()
            }

            // Expandable buttons
            if isExpanded {
                if isLocked {
                    Button {
                        onUnlock()
                    } label: {
                        Label {
                            Text("common.unlockWithPro")
                                .font(.caption.weight(.medium))
                        } icon: {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                        }
                    }
                    .primaryButton(size: .regular, width: .flexible, shape: .roundedRectangle(radius: 10))
                } else {
                    HStack(spacing: 8) {
                        Button {
                            onEdit()
                        } label: {
                            Label {
                                Text("common.edit")
                                    .font(.caption.weight(.medium))
                            } icon: {
                                Image(systemName: "pencil")
                                    .font(.caption2)
                            }
                        }
                        .secondaryButton(size: .regular, width: .flexible, shape: .roundedRectangle(radius: 10))

                        Button {
                            onStart()
                        } label: {
                            Label {
                                Text("trailList.startButton")
                                    .font(.caption.weight(.medium))
                            } icon: {
                                Image(systemName: "play.fill")
                                    .font(.caption2)
                            }
                        }
                        .primaryButton(size: .regular, width: .flexible, shape: .roundedRectangle(radius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(TM.bgSecondary)
        .containerShape(.rect(cornerRadius: 18, style: .continuous))
        .animation(.snappy(duration: 0.3), value: isExpanded)
        .onTapGesture {
            onTap()
        }
    }

    private func statItem(value: String, unit: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(TM.textPrimary)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(TM.textMuted)
        }
    }
}

#Preview("Liste vide") {
    NavigationStack {
        TrailListView(
            store: Store(initialState: TrailListStore.State()) {
                TrailListStore()
            }
        )
    }
}

#Preview("Avec parcours") {
    NavigationStack {
        TrailListView(
            store: Store(
                initialState: TrailListStore.State(
                    trails: [
                        TrailListItem(
                            trail: Trail(
                                id: 1,
                                name: "Tour du Mont Blanc",
                                createdAt: Date().addingTimeInterval(-86400 * 7),
                                distance: 42_500,
                                dPlus: 2_850
                            ),
                            milestoneCount: 12,
                            trackPoints: [],
                            milestones: []
                        ),
                        TrailListItem(
                            trail: Trail(
                                id: 2,
                                name: "Traversée des Bauges",
                                createdAt: Date().addingTimeInterval(-86400 * 3),
                                distance: 28_300,
                                dPlus: 1_650
                            ),
                            milestoneCount: 8,
                            trackPoints: [],
                            milestones: []
                        ),
                        TrailListItem(
                            trail: Trail(
                                id: 3,
                                name: "Boucle Col de la Croix",
                                createdAt: Date().addingTimeInterval(-86400),
                                distance: 15_800,
                                dPlus: 890
                            ),
                            milestoneCount: 5,
                            trackPoints: [],
                            milestones: []
                        ),
                        TrailListItem(
                            trail: Trail(
                                id: 4,
                                name: "UTMB CCC",
                                createdAt: Date(),
                                distance: 101_000,
                                dPlus: 6_100
                            ),
                            milestoneCount: 24,
                            trackPoints: [],
                            milestones: []
                        ),
                    ]
                )
            ) {
                TrailListStore()
            }
        )
    }
}
