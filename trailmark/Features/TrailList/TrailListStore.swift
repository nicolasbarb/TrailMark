import Foundation
import ComposableArchitecture

@Reducer
struct TrailListStore {
    @ObservableState
    struct State: Equatable {
        var trails: [TrailListItem] = []
        var isLoading = false
        @Shared(.inMemory("isPremium")) var isPremium = false
        var showExpiredAlert = false
        var expandedTrailId: Int64? = nil
        @Shared(.appStorage("trailListVisitCount")) var trailListVisitCount = 0
        @Shared(.appStorage("completedRunsCount")) var completedRunsCount = 0
        @Shared(.appStorage("hasRequestedReview")) var hasRequestedReview = false
        @Presents var destination: Destination.State?
    }

    enum Action: Equatable {
        case onAppear
        case trailsLoaded([TrailListItem])
        case premiumStatusChanged(Bool)
        case addButtonTapped
        case editTrailTapped(TrailListItem)
        case startTrailTapped(TrailListItem)
        case trailCardTapped(TrailListItem)
        case unlockTapped
        case deleteTrailTapped(TrailListItem)
        case trailDeleted
        case settingsTapped
        case proBadgeTapped
        case dismissExpiredAlert
        case renewTapped
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)

        // MARK: - Internal actions (for testability)
        case _incrementVisitCount
        case _checkFirstVisitPaywall
        case _loadTrails
        case _startPremiumStream
        case _requestReviewIfNeeded

        #if DEBUG
        // DEBUG: Simuler l'expiration
        case debugSimulateExpiration
        #endif
    }

    // MARK: - Delegate

    enum Delegate: Equatable {
        case navigateToEditor(Int64)
        case navigateToEditorWithPendingData(PendingTrailData)
        case navigateToRun(Int64)
        case navigateToSettings
    }
    
    enum TrailListCancelID: Equatable/*, Hashable, Sendable*/ {
        case premiumStatus
    }


    @Dependency(\.database) var database
    @Dependency(\.subscription) var subscription
    @Dependency(\.storeKit) var storeKit

    var body: some Reducer<State, Action> {
        TrailListAnalyticsReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .concatenate(
                    .send(._incrementVisitCount),
                    .send(._checkFirstVisitPaywall),
                    .send(._requestReviewIfNeeded),
                    .merge(
                        .send(._loadTrails),
                        .send(._startPremiumStream)
                    )
                )

            case ._incrementVisitCount:
                state.$trailListVisitCount.withLock { $0 += 1 }
                return .none

            case ._checkFirstVisitPaywall:
                if state.trailListVisitCount == 1 {
                    state.destination = .paywall(PaywallStore.State())
                }
                return .none

            case ._loadTrails:
                return .run { send in
                    let trails = try await database.fetchAllTrails()
                    await send(.trailsLoaded(trails))
                }

            case ._startPremiumStream:
                return .run { send in
                    for await isPremium in subscription.premiumStatusStream() {
                        await send(.premiumStatusChanged(isPremium))
                    }
                }
                .cancellable(id: TrailListCancelID.premiumStatus)

            case ._requestReviewIfNeeded:
                guard state.completedRunsCount >= 1 && !state.hasRequestedReview else {
                    return .none
                }
                state.$hasRequestedReview.withLock { $0 = true }
                return .run { [storeKit] _ in
                    await storeKit.requestReview()
                }

            case let .trailsLoaded(trails):
                state.isLoading = false
                state.trails = trails
                return .none

            case let .premiumStatusChanged(isPremium):
                // Détecter l'expiration : était premium, ne l'est plus
                let wasExpired = state.isPremium && !isPremium
                state.$isPremium.withLock { $0 = isPremium }
                if wasExpired {
                    state.showExpiredAlert = true
                }
                return .none

            case .settingsTapped:
                return .send(.delegate(.navigateToSettings))

            case .proBadgeTapped:
                state.destination = .subscriptionInfo(SubscriptionInfoStore.State())
                return .none

            case .dismissExpiredAlert:
                state.showExpiredAlert = false
                return .none

            case .renewTapped:
                state.showExpiredAlert = false
                state.destination = .paywall(PaywallStore.State())
                return .none

            #if DEBUG
            case .debugSimulateExpiration:
                // Simule la transition premium → non-premium
                if state.isPremium {
                    state.$isPremium.withLock { $0 = false }
                    state.showExpiredAlert = true
                }
                return .none
            #endif

            case .addButtonTapped:
                // Free users are limited to 1 trail
                if !state.isPremium && state.trails.count >= 1 {
                    state.destination = .paywall(PaywallStore.State())
                } else {
                    state.destination = .importGPX(ImportStore.State())
                }
                return .none

            case let .editTrailTapped(item):
                guard let trailId = item.trail.id else { return .none }
                return .send(.delegate(.navigateToEditor(trailId)))

            case let .startTrailTapped(item):
                guard let trailId = item.trail.id else { return .none }
                return .send(.delegate(.navigateToRun(trailId)))

            case let .trailCardTapped(item):
                if state.expandedTrailId == item.trail.id {
                    state.expandedTrailId = nil
                } else {
                    state.expandedTrailId = item.trail.id
                }
                return .none

            case .unlockTapped:
                state.destination = .paywall(PaywallStore.State())
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

            case .destination(.presented(.importGPX(.importCompleted(let pendingData)))):
                state.destination = nil
                // Navigate to editor with pending data (will save in background)
                return .run { send in
                    // Small delay to allow sheet dismissal
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.delegate(.navigateToEditorWithPendingData(pendingData)))
                }

            case .destination(.presented(.paywall(.purchaseCompleted))),
                 .destination(.presented(.paywall(.restoreCompleted))):
                // RevenueCat handles the purchase — isPremium updated via premiumStatusStream
                state.$isPremium.withLock { $0 = true }
                return .none

            case .destination(.dismiss):
                // Reload trails when returning from any destination
                return .run { send in
                    let trails = try await database.fetchAllTrails()
                    await send(.trailsLoaded(trails))
                }

            case .delegate:
                return .none

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }

    // MARK: - Destination (modals only)

    @Reducer
    struct Destination {
        @ObservableState
        enum State: Equatable {
            case importGPX(ImportStore.State)
            case paywall(PaywallStore.State)
            case subscriptionInfo(SubscriptionInfoStore.State)
        }

        enum Action: Equatable {
            case importGPX(ImportStore.Action)
            case paywall(PaywallStore.Action)
            case subscriptionInfo(SubscriptionInfoStore.Action)
        }

        var body: some Reducer<State, Action> {
            Scope(state: \.importGPX, action: \.importGPX) {
                ImportStore()
            }
            Scope(state: \.paywall, action: \.paywall) {
                PaywallStore()
            }
            Scope(state: \.subscriptionInfo, action: \.subscriptionInfo) {
                SubscriptionInfoStore()
            }
        }
    }
}
