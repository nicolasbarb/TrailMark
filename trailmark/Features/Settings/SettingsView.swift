import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsStore>

    var body: some View {
        List {
            Section("Abonnement") {
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "tag", color: TM.textSecondary)
                    Text("Offre actuelle")
                    Spacer()
                    if store.isPremium {
                        ProBadge()
                    } else {
                        Text("Gratuit")
                            .font(.body)
                            .foregroundStyle(TM.textMuted)
                    }
                }

                if !store.isPremium {
                    Button {
                        Haptic.medium.trigger()
                        store.send(.upgradeTapped)
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(systemName: "crown.fill", color: TM.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Passer à PRO")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(TM.textPrimary)
                                Text("Prépare chaque course sans aucune limite.")
                                    .font(.caption)
                                    .foregroundStyle(TM.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TM.textMuted)
                        }
                    }
                }
            }
            .listRowBackground(TM.bgSecondary)

            Section("À propos") {
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "info.circle", color: TM.textSecondary)
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                        .foregroundStyle(TM.textMuted)
                }

                Link(destination: URL(string: "mailto:nicolas.barb.pro@gmail.com?subject=Retour%20PaceMark")!) {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: "envelope.fill", color: .blue)
                        Text("Signaler un problème")
                            .foregroundStyle(TM.textPrimary)
                    }
                }
            }
            .listRowBackground(TM.bgSecondary)
        }
        .listStyle(.automatic)
        .scrollContentBackground(.hidden)
        .background(TM.bgPrimary)
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.large)
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
    }
}

// MARK: - Settings Icon

private struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(color, in: .rect(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            store: Store(initialState: SettingsStore.State()) {
                SettingsStore()
            }
        )
    }
}
