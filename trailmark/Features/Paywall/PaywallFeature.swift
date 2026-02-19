import Foundation
import ComposableArchitecture

@Reducer
struct PaywallFeature {
    @ObservableState
    struct State: Equatable {
        var packages: [SubscriptionPackage] = []
        var isLoading = true
        var isPurchasing = false
        var isRestoring = false
        var errorMessage: String?
        var purchaseSucceeded = false
    }

    enum Action: Equatable {
        case onAppear
        case packagesLoaded([SubscriptionPackage])
        case loadingFailed(String)
        case purchaseTapped(SubscriptionPackage)
        case purchaseCompleted(Bool)
        case purchaseFailed(String)
        case restoreTapped
        case restoreCompleted(Bool)
        case restoreFailed(String)
        case dismissError
        case closeButtonTapped
    }

    @Dependency(\.subscription) var subscription
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let packages = try await subscription.fetchOfferings()
                        await send(.packagesLoaded(packages))
                    } catch {
                        await send(.loadingFailed(error.localizedDescription))
                    }
                }

            case let .packagesLoaded(packages):
                state.isLoading = false
                state.packages = packages
                return .none

            case let .loadingFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case let .purchaseTapped(package):
                state.isPurchasing = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let success = try await subscription.purchase(package)
                        await send(.purchaseCompleted(success))
                    } catch {
                        await send(.purchaseFailed(error.localizedDescription))
                    }
                }

            case let .purchaseCompleted(success):
                state.isPurchasing = false
                if success {
                    state.purchaseSucceeded = true
                }
                return .none

            case let .purchaseFailed(message):
                state.isPurchasing = false
                state.errorMessage = message
                return .none

            case .restoreTapped:
                state.isRestoring = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let success = try await subscription.restorePurchases()
                        await send(.restoreCompleted(success))
                    } catch {
                        await send(.restoreFailed(error.localizedDescription))
                    }
                }

            case let .restoreCompleted(success):
                state.isRestoring = false
                if success {
                    state.purchaseSucceeded = true
                } else {
                    state.errorMessage = "Aucun achat à restaurer"
                }
                return .none

            case let .restoreFailed(message):
                state.isRestoring = false
                state.errorMessage = message
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .closeButtonTapped:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }
}
