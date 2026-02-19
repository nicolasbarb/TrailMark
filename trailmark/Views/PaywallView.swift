import SwiftUI
import ComposableArchitecture

struct PaywallView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        store.send(.closeButtonTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TM.textMuted)
                            .frame(width: 32, height: 32)
                            .background(TM.bgSecondary, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 32) {
                        header
                        benefits
                        packages
                        restoreButton
                        legalText
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }

            if store.isPurchasing || store.isRestoring {
                loadingOverlay
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert(
            "Erreur",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.dismissError) } }
            )
        ) {
            Button("OK") {
                store.send(.dismissError)
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(TM.accent.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(TM.accent)
            }

            VStack(spacing: 8) {
                Text("PREMIUM")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.accent)
                    .tracking(4)

                Text("Parcours illimités")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TM.textPrimary)

                Text("Créez autant de guides vocaux que vous voulez")
                    .font(.subheadline)
                    .foregroundStyle(TM.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(spacing: 12) {
            benefitRow(icon: "infinity", text: "Parcours illimités")
            benefitRow(icon: "flag.fill", text: "Jalons illimités par parcours")
            benefitRow(icon: "icloud.fill", text: "Sauvegarde locale sécurisée")
            benefitRow(icon: "heart.fill", text: "Soutenez le développement")
        }
        .padding(20)
        .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(TM.accent)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(TM.textPrimary)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(TM.success)
        }
    }

    // MARK: - Packages

    private var packages: some View {
        VStack(spacing: 12) {
            if store.isLoading {
                ProgressView()
                    .tint(TM.accent)
                    .frame(height: 140)
            } else {
                // Annual package (recommended)
                if let annual = store.packages.first(where: { $0.type == .annual }) {
                    packageButton(package: annual, isRecommended: true)
                }

                // Monthly package
                if let monthly = store.packages.first(where: { $0.type == .monthly }) {
                    packageButton(package: monthly, isRecommended: false)
                }
            }
        }
    }

    private func packageButton(package: SubscriptionPackage, isRecommended: Bool) -> some View {
        Button {
            store.send(.purchaseTapped(package))
        } label: {
            VStack(spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(package.type == .annual ? "Annuel" : "Mensuel")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isRecommended ? .white : TM.textPrimary)

                            if isRecommended {
                                Text("-58%")
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                                    .foregroundStyle(TM.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }

                        if let monthlyPrice = package.localizedPricePerMonth {
                            Text("\(monthlyPrice)/mois")
                                .font(.caption)
                                .foregroundStyle(isRecommended ? .white.opacity(0.8) : TM.textMuted)
                        }
                    }

                    Spacer()

                    Text(package.localizedPrice)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(isRecommended ? .white : TM.textPrimary)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isRecommended ? AnyShapeStyle(TM.accentGradient) : AnyShapeStyle(TM.bgSecondary))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isRecommended ? Color.clear : TM.border, lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            store.send(.restoreTapped)
        } label: {
            Text("Restaurer mes achats")
                .font(.subheadline)
                .foregroundStyle(TM.textSecondary)
        }
    }

    // MARK: - Legal Text

    private var legalText: some View {
        VStack(spacing: 8) {
            Text("L'abonnement se renouvelle automatiquement sauf annulation au moins 24h avant la fin de la période. Le paiement est débité sur votre compte iTunes.")
                .font(.caption2)
                .foregroundStyle(TM.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Conditions d'utilisation", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Confidentialité", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            }
            .font(.caption2)
            .foregroundStyle(TM.accent)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)

                Text(store.isRestoring ? "Restauration..." : "Achat en cours...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    PaywallView(
        store: Store(
            initialState: PaywallFeature.State(
                packages: [
                    SubscriptionPackage(
                        id: "monthly",
                        type: .monthly,
                        localizedPrice: "1,99 €",
                        localizedPricePerMonth: "1,99 €"
                    ),
                    SubscriptionPackage(
                        id: "annual",
                        type: .annual,
                        localizedPrice: "9,99 €",
                        localizedPricePerMonth: "0,83 €"
                    )
                ],
                isLoading: false
            )
        ) {
            PaywallFeature()
        }
    )
}
