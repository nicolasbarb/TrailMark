import SwiftUI
import ComposableArchitecture
import RevenueCat
import RevenueCatUI

struct PaywallContainerView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
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
