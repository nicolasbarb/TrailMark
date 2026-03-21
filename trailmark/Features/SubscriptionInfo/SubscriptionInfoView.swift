import SwiftUI
import StoreKit
import ComposableArchitecture

struct SubscriptionInfoView: View {
    @Bindable var store: StoreOf<SubscriptionInfoStore>

    var body: some View {
        NavigationStack {
            ZStack {
                TM.bgPrimary.ignoresSafeArea()

                if store.isLoading {
                    ProgressView()
                        .tint(TM.accent)
                } else {
                    subscriptionContent(store.subscriptionInfo)
                }
            }
            .navigationTitle("Mon abonnement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        store.send(.closeButtonTapped)
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .manageSubscriptionsSheet(
                isPresented: Binding(
                    get: { store.showManageSheet },
                    set: { if !$0 { store.send(.manageSheetDismissed) } }
                )
            )
        }
    }

    // MARK: - Content

    private func subscriptionContent(_ info: SubscriptionInfo?) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Plan card
                VStack(spacing: 16) {
                    ProBadge()
                        .scaleEffect(1.5)
                        .padding(.top, 4)

                    Text(info?.planType.displayName ?? "Premium")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(TM.textPrimary)

                    VStack(spacing: 12) {
                        if let expirationDate = info?.expirationDate {
                            let willRenew = info?.willRenew ?? false
                            infoRow(
                                icon: willRenew ? "arrow.triangle.2.circlepath" : "calendar",
                                label: willRenew ? "Prochain renouvellement" : "Expire le",
                                value: expirationDate.formatted(date: .long, time: .omitted)
                            )
                        }

                        infoRow(
                            icon: "checkmark.seal.fill",
                            label: "Statut",
                            value: info?.willRenew == false ? "Non renouvelable" : "Actif"
                        )
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(TM.bgSecondary)
                .clipShape(.rect(cornerRadius: 18, style: .continuous))

                // Manage button
                Button {
                    Haptic.light.trigger()
                    store.send(.manageSubscriptionTapped)
                } label: {
                    Text("Gérer l'abonnement")
                }
                .secondaryButton(size: .large, width: .flexible, shape: .capsule)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(TM.textSecondary)
            } icon: {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(TM.accent)
                    .frame(width: 20)
            }

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TM.textPrimary)
        }
    }
}

// MARK: - PlanType Display

private extension SubscriptionInfo.PlanType {
    var displayName: String {
        switch self {
        case .monthly: "Abonnement mensuel"
        case .annual: "Abonnement annuel"
        case .unknown: "Abonnement Premium"
        }
    }
}

#Preview {
    SubscriptionInfoView(
        store: Store(initialState: SubscriptionInfoStore.State()) {
            SubscriptionInfoStore()
        }
    )
}
