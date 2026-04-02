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

    @State private var showEmptyContent = false

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            // 3-step flow
            HStack(spacing: 12) {
                emptyStateStep(
                    symbol: "square.and.arrow.down",
                    label: String(localized: "trailList.emptyState.step.import")
                )
                .animatedAppearance(show: showEmptyContent, delay: 0.0)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TM.textMuted)
                    .animatedAppearance(show: showEmptyContent, delay: 0.15)

                emptyStateStep(
                    symbol: "flag",
                    label: String(localized: "trailList.emptyState.step.milestones")
                )
                .animatedAppearance(show: showEmptyContent, delay: 0.3)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TM.textMuted)
                    .animatedAppearance(show: showEmptyContent, delay: 0.45)

                emptyStateStep(
                    symbol: "play.fill",
                    label: String(localized: "trailList.emptyState.step.guidance")
                )
                .animatedAppearance(show: showEmptyContent, delay: 0.6)
            }

            // Title + description
            VStack(spacing: 6) {
                Text("trailList.emptyState.title")
                    .font(.headline)
                    .foregroundStyle(TM.textSecondary)

                Text("trailList.emptyState.description")
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
                    .multilineTextAlignment(.center)
            }
            .animatedAppearance(show: showEmptyContent, delay: 0.8)

            // CTA
            Button {
                Haptic.medium.trigger()
                store.send(.addButtonTapped)
            } label: {
                Text("trailList.importButton")
            }
            .primaryButton(size: .large, width: .fitted, shape: .capsule)
            .animatedAppearance(show: showEmptyContent, delay: 1.0)

            Spacer()
        }
        .onAppear {
            guard !showEmptyContent else { return }
            withAnimation(.snappy(duration: 0.4)) {
                showEmptyContent = true
            }
        }
    }

    private func emptyStateStep(symbol: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(TM.accent)
                .frame(width: 48, height: 48)
                .background(TM.accent.opacity(0.1), in: .rect(cornerRadius: 14))

            Text(label)
                .font(.caption2)
                .foregroundStyle(TM.textMuted)
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
                            store.send(.trailCardTapped(item), animation: .snappy(duration: 0.4, extraBounce: 0.24))
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()

                Text(trail.createdAtDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(TM.textMuted)
            }

            // Elevation profile — grows when expanded
            if !item.trackPoints.isEmpty {
                ZStack {
                    ElevationProfilePreview(
                        trackPoints: item.trackPoints,
                        milestones: item.milestones
                    )
                    .frame(height: 60)
                    .clipShape(.rect(cornerRadius: 8))

                    if isLocked {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)

                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.title3)
                                .foregroundStyle(TM.textMuted)
                            ProBadge()
                        }
                    }
                }
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
            .opacity(isLocked ? 0.5 : 1)

            // Expandable buttons with stagger
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
                    .transition(.move(edge: .top).combined(with: .blurReplace))
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
                    .transition(.move(edge: .top).combined(with: .blurReplace))
                }
            }
        }
        .padding(16)
        .background(TM.bgSecondary)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isExpanded ? TM.accent.opacity(0.4) : TM.border.opacity(0.3),
                    lineWidth: isExpanded ? 1.5 : 0.5
                )
        )
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
    let samplePoints: [TrackPoint] = (0..<100).map { i in
        let progress = Double(i) / 99.0
        let elevation = 1200 + 800 * sin(progress * .pi) + 200 * sin(progress * 4 * .pi)
        return TrackPoint(
            index: i,
            latitude: 45.8 + progress * 0.1,
            longitude: 6.8 + progress * 0.05,
            elevation: elevation,
            distance: progress * 42500
        )
    }

    let sampleMilestones: [Milestone] = [
        Milestone(pointIndex: 25, latitude: 45.825, longitude: 6.8125, elevation: 1800, distance: 10625, type: .climb, message: "Montée"),
        Milestone(pointIndex: 50, latitude: 45.85, longitude: 6.825, elevation: 2000, distance: 21250, type: .descent, message: "Descente"),
        Milestone(pointIndex: 75, latitude: 45.875, longitude: 6.8375, elevation: 1600, distance: 31875, type: .info, message: "Info"),
    ]

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
                            milestoneCount: 3,
                            trackPoints: samplePoints,
                            milestones: sampleMilestones
                        ),
                        TrailListItem(
                            trail: Trail(
                                id: 2,
                                name: "Traversée des Bauges",
                                createdAt: Date().addingTimeInterval(-86400 * 3),
                                distance: 28_300,
                                dPlus: 1_650
                            ),
                            milestoneCount: 2,
                            trackPoints: (0..<80).map { i in
                                let progress = Double(i) / 79.0
                                let elevation = 800 + 600 * sin(progress * .pi * 1.5)
                                return TrackPoint(index: i, latitude: 45.6 + progress * 0.08, longitude: 6.1 + progress * 0.04, elevation: elevation, distance: progress * 28300)
                            },
                            milestones: [
                                Milestone(pointIndex: 30, latitude: 45.63, longitude: 6.115, elevation: 1200, distance: 10613, type: .climb, message: "Montée"),
                                Milestone(pointIndex: 60, latitude: 45.66, longitude: 6.13, elevation: 1000, distance: 21225, type: .danger, message: "Danger"),
                            ]
                        ),
                        TrailListItem(
                            trail: Trail(
                                id: 3,
                                name: "UTMB CCC",
                                createdAt: Date(),
                                distance: 101_000,
                                dPlus: 6_100
                            ),
                            milestoneCount: 0,
                            trackPoints: (0..<120).map { i in
                                let progress = Double(i) / 119.0
                                let elevation = 1000 + 1500 * sin(progress * .pi * 2) + 500 * sin(progress * 7 * .pi)
                                return TrackPoint(index: i, latitude: 45.9 + progress * 0.15, longitude: 6.9 + progress * 0.08, elevation: max(800, elevation), distance: progress * 101000)
                            },
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

// MARK: - Stagger Animation

private extension View {
    func animatedAppearance(show: Bool, delay: Double) -> some View {
        self
            .opacity(show ? 1 : 0)
            .blur(radius: show ? 0 : 8)
            .animation(.snappy(duration: 0.4).delay(delay), value: show)
    }
}
