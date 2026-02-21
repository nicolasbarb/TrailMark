import Foundation
import ComposableArchitecture

@Reducer
struct TrailListFeature {
    @ObservableState
    struct State: Equatable {
        var trails: [TrailListItem] = []
        var isLoading = false
        var isPremium = false
        var showExpiredAlert = false
        @Shared(.appStorage("trailListVisitCount")) var trailListVisitCount = 0
        @Presents var destination: Destination.State?
    }

    enum Action: Equatable {
        case onAppear
        case trailsLoaded([TrailListItem])
        case premiumStatusChanged(Bool)
        case addButtonTapped
        case editTrailTapped(TrailListItem)
        case startTrailTapped(TrailListItem)
        case deleteTrailTapped(TrailListItem)
        case trailDeleted
        case navigateToEditor(Int64)
        case openImport
        case dismissExpiredAlert
        case renewTapped
        case destination(PresentationAction<Destination.Action>)

        // DEBUG: Simuler l'expiration
        case debugSimulateExpiration
    }
    
    enum TrailListCancelID: Equatable/*, Hashable, Sendable*/ {
        case premiumStatus
    }


    @Dependency(\.database) var database
    @Dependency(\.subscription) var subscription

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true

                // Incrémenter le compteur de visites
                state.$trailListVisitCount.withLock { $0 += 1 }

                // Afficher le paywall à la première visite
                if state.trailListVisitCount == 1 {
                    state.destination = .paywall(PaywallFeature.State())
                }

                return .merge(
                    .run { send in
                        let trails = try await database.fetchAllTrails()
                        await send(.trailsLoaded(trails))
                    },
                    .run { send in
                        for await isPremium in subscription.premiumStatusStream() {
                            await send(.premiumStatusChanged(isPremium))
                        }
                    }
                    .cancellable(id: TrailListCancelID.premiumStatus)
                )

            case let .trailsLoaded(trails):
                state.isLoading = false
                state.trails = trails
                return .none

            case let .premiumStatusChanged(isPremium):
                // Détecter l'expiration : était premium, ne l'est plus
                let wasExpired = state.isPremium && !isPremium
                state.isPremium = isPremium
                if wasExpired {
                    state.showExpiredAlert = true
                }
                return .none

            case .dismissExpiredAlert:
                state.showExpiredAlert = false
                return .none

            case .renewTapped:
                state.showExpiredAlert = false
                state.destination = .paywall(PaywallFeature.State())
                return .none

            #if DEBUG
            case .debugSimulateExpiration:
                // Simule la transition premium → non-premium
                if state.isPremium {
                    state.isPremium = false
                    state.showExpiredAlert = true
                }
                return .none
            #endif

            case .addButtonTapped:
                // Free users are limited to 1 trail
                if !state.isPremium && state.trails.count >= 1 {
                    state.destination = .paywall(PaywallFeature.State())
                } else {
                    state.destination = .importGPX(ImportFeature.State())
                }
                return .none

            case let .editTrailTapped(item):
                guard let trailId = item.trail.id else { return .none }
                state.destination = .editor(EditorFeature.State(trailId: trailId))
                return .none

            case let .startTrailTapped(item):
                guard let trailId = item.trail.id else { return .none }
                state.destination = .run(RunFeature.State(trailId: trailId))
                return .none

            case let .deleteTrailTapped(item):
                guard let trailId = item.trail.id else { return .none }
                return .run { send in
                    try await database.deleteTrail(trailId)
                    await send(.trailDeleted)
                }

            case .trailDeleted:
                return .run { send in
                    let trails = try await database.fetchAllTrails()
                    await send(.trailsLoaded(trails))
                }

            case let .navigateToEditor(trailId):
                state.destination = .editor(EditorFeature.State(trailId: trailId))
                return .none

            case .openImport:
                state.destination = .importGPX(ImportFeature.State())
                return .none

            case .destination(.presented(.importGPX(.importCompleted(let trail)))):
                state.destination = nil
                guard let trailId = trail.id else { return .none }
                // Navigate to editor after successful import
                return .run { [trailId] send in
                    // Small delay to allow sheet dismissal
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.navigateToEditor(trailId))
                }

            case .destination(.presented(.paywall(.purchaseCompleted))):
                // Purchase succeeded, dismiss paywall and open import
                state.destination = nil
                state.isPremium = true
                return .run { send in
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.openImport)
                }

            case .destination(.presented(.paywall(.restoreCompleted))):
                // Restore succeeded, dismiss paywall and open import
                state.destination = nil
                state.isPremium = true
                return .run { send in
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.openImport)
                }

            case .destination(.dismiss):
                // Reload trails when returning from any destination
                return .run { send in
                    let trails = try await database.fetchAllTrails()
                    await send(.trailsLoaded(trails))
                }

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }

    // MARK: - Destination

    @Reducer
    struct Destination {
        @ObservableState
        enum State: Equatable {
            case importGPX(ImportFeature.State)
            case editor(EditorFeature.State)
            case run(RunFeature.State)
            case paywall(PaywallFeature.State)
        }

        enum Action: Equatable {
            case importGPX(ImportFeature.Action)
            case editor(EditorFeature.Action)
            case run(RunFeature.Action)
            case paywall(PaywallFeature.Action)
        }

        var body: some Reducer<State, Action> {
            Scope(state: \.importGPX, action: \.importGPX) {
                ImportFeature()
            }
            Scope(state: \.editor, action: \.editor) {
                EditorFeature()
            }
            Scope(state: \.run, action: \.run) {
                RunFeature()
            }
            Scope(state: \.paywall, action: \.paywall) {
                PaywallFeature()
            }
        }
    }
}
