import SwiftUI
import ComposableArchitecture
import RevenueCat
import RevenueCatUI

struct PaywallContainerView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        // Utilise automatiquement l'offering "current" et le paywall
        // configuré dans le dashboard RevenueCat.
        // Pour vérifier : regarde les logs Xcode (Purchases.logLevel = .debug)
        // Tu verras : "Offering 'xxx' loaded with paywall 'yyy'"
        RevenueCatUI.PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in
                store.send(.purchaseCompleted)
            }
            .onRestoreCompleted { _ in
                store.send(.restoreCompleted)
            }
    }
}

#Preview {
    PaywallContainerView(
        store: Store(initialState: PaywallFeature.State()) {
            PaywallFeature()
        }
    )
}
