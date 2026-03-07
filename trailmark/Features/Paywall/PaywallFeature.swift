import Foundation
import ComposableArchitecture

@Reducer
struct PaywallFeature {
    @ObservableState
    struct State: Equatable {
        var packages: [SubscriptionPackage] = []
        var selectedPackage: SubscriptionPackage?
        var isLoading = false
        var isPurchasing = false
        var purchaseSucceeded = false
        var error: String?
    }

    enum Action: Equatable {
        case onAppear
        case packagesLoaded([SubscriptionPackage])
        case loadingFailed(String)
        case packageSelected(SubscriptionPackage)
        case purchaseButtonTapped
        case purchaseCompleted
        case purchaseCancelled
        case purchaseFailed(String)
        case restoreButtonTapped
        case restoreCompleted
        case restoreFailed(String)
        case closeButtonTapped
        case _delayedDismiss
    }

    @Dependency(\.subscription) var subscription
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.packages.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    let packages = try await subscription.fetchOfferings()
                    await send(.packagesLoaded(packages))
                } catch: { error, send in
                    await send(.loadingFailed(error.localizedDescription))
                }

            case let .packagesLoaded(packages):
                state.isLoading = false
                state.packages = packages
                if packages.isEmpty {
                    state.error = "Aucune offre disponible pour le moment."
                } else {
                    state.selectedPackage = packages.first(where: { $0.type == .annual }) ?? packages.first
                }
                return .none

            case let .loadingFailed(message):
                state.isLoading = false
                state.error = message
                return .none

            case let .packageSelected(package):
                state.selectedPackage = package
                return .none

            case .purchaseButtonTapped:
                guard let package = state.selectedPackage else { return .none }
                state.isPurchasing = true
                state.error = nil
                return .run { send in
                    let success = try await subscription.purchase(package)
                    if success {
                        await send(.purchaseCompleted)
                    } else {
                        await send(.purchaseCancelled)
                    }
                } catch: { error, send in
                    let nsError = error as NSError
                    // RevenueCat purchase cancelled error codes
                    if nsError.domain == "RevenueCat.ErrorCode" && nsError.code == 1 {
                        await send(.purchaseCancelled)
                    } else {
                        await send(.purchaseFailed(error.localizedDescription))
                    }
                }

            case .purchaseCompleted:
                state.isPurchasing = false
                state.purchaseSucceeded = true
                return .run { send in
                    try await Task.sleep(for: .milliseconds(800))
                    await send(._delayedDismiss)
                }

            case .purchaseCancelled:
                state.isPurchasing = false
                return .none

            case let .purchaseFailed(message):
                state.isPurchasing = false
                state.error = message
                return .none

            case .restoreButtonTapped:
                state.isPurchasing = true
                state.error = nil
                return .run { send in
                    let success = try await subscription.restorePurchases()
                    if success {
                        await send(.restoreCompleted)
                    } else {
                        await send(.restoreFailed("Aucun achat trouvé"))
                    }
                } catch: { error, send in
                    await send(.restoreFailed(error.localizedDescription))
                }

            case .restoreCompleted:
                state.isPurchasing = false
                state.purchaseSucceeded = true
                return .run { send in
                    try await Task.sleep(for: .milliseconds(800))
                    await send(._delayedDismiss)
                }

            case let .restoreFailed(message):
                state.isPurchasing = false
                state.error = message
                return .none

            case .closeButtonTapped, ._delayedDismiss:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }
}
