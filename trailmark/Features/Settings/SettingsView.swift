import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsStore>

    var body: some View {
        List {
            Section("settings.subscription.section") {
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "tag")
                    Text("settings.subscription.currentPlan")
                    Spacer()
                    if store.isPremium {
                        ProBadge()
                    } else {
                        Text("settings.subscription.free")
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
                            SettingsIcon(systemName: "crown.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.subscription.upgradeCta")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(TM.textPrimary)
                                Text("settings.subscription.upgradeDescription")
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

            Section("settings.general.section") {
                NavigationLink {
                    LanguageView(
                        store: Store(initialState: LanguageStore.State()) {
                            LanguageStore()
                        }
                    )
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: "globe")
                        Text("settings.language.row")
                            .foregroundStyle(TM.textPrimary)
                    }
                }
            }
            .listRowBackground(TM.bgSecondary)

            Section("settings.about.section") {
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "info.circle")
                    Text("settings.about.version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                        .foregroundStyle(TM.textMuted)
                }

                Link(destination: URL(string: "mailto:nicolas.barb.pro@gmail.com?subject=Retour%20PaceMark")!) {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: "envelope.fill")
                        Text("settings.about.reportProblem")
                            .foregroundStyle(TM.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TM.textMuted)
                    }
                }
            }
            .listRowBackground(TM.bgSecondary)
        }
        .listStyle(.automatic)
        .scrollContentBackground(.hidden)
        .background(TM.bgPrimary)
        .navigationTitle("settings.title")
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

struct SettingsIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(TM.textPrimary, in: .rect(cornerRadius: 8, style: .continuous))
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
