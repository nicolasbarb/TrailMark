import SwiftUI
import ComposableArchitecture

struct TrailListView: View {
    @Bindable var store: StoreOf<TrailListFeature>

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                if store.trails.isEmpty && !store.isLoading {
                    emptyState
                } else {
                    trailList
                }
            }
        }
        .navigationBarHidden(true)
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
        .fullScreenCover(
            item: $store.scope(state: \.destination?.paywall, action: \.destination.paywall)
        ) { paywallStore in
            PaywallContainerView(store: paywallStore)
        }
        .alert(
            "Abonnement expiré",
            isPresented: Binding(
                get: { store.showExpiredAlert },
                set: { if !$0 { store.send(.dismissExpiredAlert) } }
            )
        ) {
            Button("Renouveler") {
                store.send(.renewTapped)
            }
            Button("Plus tard", role: .cancel) {
                store.send(.dismissExpiredAlert)
            }
        } message: {
            Text("Votre abonnement Premium a expiré. Renouvelez pour continuer à créer des parcours illimités.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("TrailMark")
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.accent)
                    if store.isPremium {
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(TM.accent, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text("Mes parcours")
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
            }

            Spacer()

            // TODO: Remettre pour tester l'expiration
            // #if DEBUG
            // if store.isPremium {
            //     Button {
            //         store.send(.debugSimulateExpiration)
            //     } label: {
            //         Image(systemName: "clock.badge.xmark")
            //             .font(.system(size: 14))
            //             .foregroundStyle(TM.textMuted)
            //             .frame(width: 32, height: 32)
            //     }
            // }
            // #endif

            Button {
                store.send(.addButtonTapped)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(TM.accent, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: TM.accent.opacity(0.3), radius: 12, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("🏔️")
                .font(.system(size: 40))

            Text("Aucun TrailMark")
                .font(.headline)
                .foregroundStyle(TM.textSecondary)

            Text("Importez un fichier GPX pour créer\nvotre premier guide vocal de trail")
                .font(.caption)
                .foregroundStyle(TM.textMuted)
                .multilineTextAlignment(.center)

            Button {
                store.send(.addButtonTapped)
            } label: {
                Text("Importer un GPX")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(TM.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Trail List

    private var trailList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(store.trails.enumerated()), id: \.element.id) { index, item in
                    let isLocked = !store.isPremium && index > 0
                    TrailCard(
                        item: item,
                        isLocked: isLocked,
                        onEdit: { store.send(.editTrailTapped(item)) },
                        onStart: { store.send(.startTrailTapped(item)) },
                        onUnlock: { store.send(.addButtonTapped) }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            store.send(.deleteTrailTapped(item))
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
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
    let onEdit: () -> Void
    let onStart: () -> Void
    let onUnlock: () -> Void

    private var trail: Trail { item.trail }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    // Name and date
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trail.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TM.textPrimary)

                        Text(trail.createdAtDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(TM.textMuted)
                    }

                    // Stats
                    HStack(spacing: 0) {
                        statColumn(
                            value: String(format: "%.1f", trail.distance / 1000),
                            unit: "km",
                            label: "Distance"
                        )

                        Divider()
                            .frame(width: 1, height: 24)
                            .background(TM.border)

                        statColumn(
                            value: "\(trail.dPlus)",
                            unit: "m",
                            label: "D+"
                        )

                        Divider()
                            .frame(width: 1, height: 24)
                            .background(TM.border)

                        statColumn(
                            value: "\(item.milestoneCount)",
                            unit: nil,
                            label: "Repères"
                        )
                    }

                    // Action buttons
                    if isLocked {
                        Button(action: onUnlock) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                Text("Débloquer avec Pro")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(TM.accentGradient, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: TM.accent.opacity(0.3), radius: 8, y: 4)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button(action: onEdit) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                        .font(.caption2)
                                    Text("Éditer")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(TM.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(TM.bgTertiary, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(TM.border, lineWidth: 1)
                                )
                            }

                            Button(action: onStart) {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.caption2)
                                    Text("Démarrer")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(TM.accentGradient, in: RoundedRectangle(cornerRadius: 10))
                                .shadow(color: TM.accent.opacity(0.3), radius: 8, y: 4)
                            }
                        }
                    }
                }
                .padding(14)
                .padding(.leading, 4)
            }
            .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(TM.bgTertiary, lineWidth: 1)
            )
        }
    }

    private func statColumn(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.textMuted)
                }
            }
            Text(label.uppercased())
                .font(.system(size: 9))
                .foregroundStyle(TM.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Liste vide") {
    TrailListView(
        store: Store(initialState: TrailListFeature.State()) {
            TrailListFeature()
        }
    )
}

#Preview("Avec parcours") {
    TrailListView(
        store: Store(
            initialState: TrailListFeature.State(
                trails: [
                    TrailListItem(
                        trail: Trail(
                            id: 1,
                            name: "Tour du Mont Blanc",
                            createdAt: Date().addingTimeInterval(-86400 * 7),
                            distance: 42_500,
                            dPlus: 2_850
                        ),
                        milestoneCount: 12
                    ),
                    TrailListItem(
                        trail: Trail(
                            id: 2,
                            name: "Traversée des Bauges",
                            createdAt: Date().addingTimeInterval(-86400 * 3),
                            distance: 28_300,
                            dPlus: 1_650
                        ),
                        milestoneCount: 8
                    ),
                    TrailListItem(
                        trail: Trail(
                            id: 3,
                            name: "Boucle Col de la Croix",
                            createdAt: Date().addingTimeInterval(-86400),
                            distance: 15_800,
                            dPlus: 890
                        ),
                        milestoneCount: 5
                    ),
                    TrailListItem(
                        trail: Trail(
                            id: 4,
                            name: "UTMB CCC",
                            createdAt: Date(),
                            distance: 101_000,
                            dPlus: 6_100
                        ),
                        milestoneCount: 24
                    ),
                ]
            )
        ) {
            TrailListFeature()
        }
    )
}
