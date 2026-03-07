import SwiftUI
import ComposableArchitecture

struct PaywallContainerView: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            if store.purchaseSucceeded {
                successView
                    .transition(.opacity)
            } else if store.isLoading {
                ProgressView()
                    .tint(TM.accent)
            } else {
                paywall
            }

            // Close button
            if !store.purchaseSucceeded {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            Haptic.light.trigger()
                            store.send(.closeButtonTapped)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TM.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(16)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(TM.success)

            Text("Bienvenue dans PaceMark PRO")
                .font(.title3.weight(.bold))
                .foregroundStyle(TM.textPrimary)

            Text("Toutes les fonctionnalités sont débloquées.")
                .font(.subheadline)
                .foregroundStyle(TM.textSecondary)

            Spacer()
        }
    }

    // MARK: - Paywall Content

    private var paywall: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 56)
                    .padding(.horizontal, 28)

                // Features
                featuresList
                    .padding(.top, 32)
                    .padding(.horizontal, 28)

                // Pricing cards
                pricingCards
                    .padding(.top, 32)
                    .padding(.horizontal, 20)

                // CTA button
                ctaButton
                    .padding(.top, 28)
                    .padding(.horizontal, 28)

                // Error
                if let error = store.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TM.danger)
                        .padding(.top, 12)
                }

                // Restore + legal
                footer
                    .padding(.top, 20)
                    .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            // App name + Pro badge
            HStack(spacing: 8) {
                Text("PaceMark")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.accent)

                Text("PRO")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(TM.accent, in: Capsule())
            }

            Text("Passe au niveau\nsupérieur")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(TM.textPrimary)

            Text("Débloquer tout le potentiel de PaceMark\npour préparer chaque course comme un pro.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(TM.textSecondary)
        }
    }

    // MARK: - Features List

    private var featuresList: some View {
        VStack(spacing: 16) {
            featureRow(
                icon: "map.fill",
                title: "Parcours illimités",
                subtitle: "Importe autant de GPX que tu veux"
            )
            featureRow(
                icon: "mappin.and.ellipse",
                title: "Repères illimités",
                subtitle: "Place tous les jalons nécessaires"
            )
            featureRow(
                icon: "sparkles",
                title: "Détection automatique",
                subtitle: "Les montées et descentes sont analysées pour toi"
            )
            featureRow(
                icon: "person.fill",
                title: "Soutiens un dev indépendant",
                subtitle: "PaceMark est conçu par un passionné de trail"
            )
            featureRow(
                icon: "arrow.up.circle.fill",
                title: "Futures fonctionnalités PRO",
                subtitle: "Accès prioritaire aux nouvelles features"
            )
        }
        .padding(20)
        .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(TM.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TM.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
            }

            Spacer()
        }
    }

    // MARK: - Pricing Cards

    private var pricingCards: some View {
        HStack(spacing: 12) {
            if let annual = store.packages.first(where: { $0.type == .annual }) {
                pricingCard(
                    package: annual,
                    label: "Annuel",
                    priceDetail: annual.localizedPricePerMonth.map { "\($0)/mois" },
                    badge: "Populaire",
                    isSelected: store.selectedPackage?.id == annual.id
                )
            }

            if let monthly = store.packages.first(where: { $0.type == .monthly }) {
                pricingCard(
                    package: monthly,
                    label: "Mensuel",
                    priceDetail: nil,
                    badge: nil,
                    isSelected: store.selectedPackage?.id == monthly.id
                )
            }
        }
    }

    private func pricingCard(
        package: SubscriptionPackage,
        label: String,
        priceDetail: String?,
        badge: String?,
        isSelected: Bool
    ) -> some View {
        Button {
            Haptic.selection.trigger()
            store.send(.packageSelected(package))
        } label: {
            VStack(spacing: 8) {
                // Badge
                if let badge {
                    Text(badge.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TM.accent, in: Capsule())
                } else {
                    Spacer().frame(height: 19)
                }

                // Label
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TM.textSecondary)

                // Price
                Text(package.localizedPrice)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.textPrimary)

                // Price detail
                if let priceDetail {
                    Text(priceDetail)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.accent)
                } else {
                    Text("/mois")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.textMuted)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? TM.accent.opacity(0.08) : TM.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? TM.accent : TM.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            Haptic.heavy.trigger()
            store.send(.purchaseButtonTapped)
        } label: {
            Group {
                if store.isPurchasing {
                    ProgressView()
                } else {
                    Text("Débloquer PRO")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .primaryButton(size: .large, width: .flexible, shape: .capsule)
        .disabled(store.isPurchasing || store.selectedPackage == nil)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Haptic.light.trigger()
                store.send(.restoreButtonTapped)
            } label: {
                Text("Restaurer les achats")
                    .underline()
            }
            .tertiaryButton(size: .mini, tint: TM.textMuted)
            .disabled(store.isPurchasing)

            Text("Paiement sécurisé via App Store\nAnnulation possible à tout moment")
                .font(.caption2)
                .foregroundStyle(TM.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Conditions d'utilisation", destination: Links.termsOfUse)
                Link("Politique de confidentialité", destination: Links.privacyPolicy)
            }
            .font(.caption2)
            .foregroundStyle(TM.textMuted)
        }
    }

    // MARK: - Links

    private enum Links {
        static let termsOfUse = URL(string: "https://nicolasbarb.github.io/PaceMark/terms.html")!
        static let privacyPolicy = URL(string: "https://nicolasbarb.github.io/PaceMark/privacy.html")!
    }
}

// MARK: - Previews

#Preview("Loading") {
    PaywallContainerView(
        store: Store(initialState: PaywallFeature.State(isLoading: true)) {
            PaywallFeature()
        }
    )
}

#Preview("Loaded") {
    PaywallContainerView(
        store: Store(
            initialState: PaywallFeature.State(
                packages: [
                    SubscriptionPackage(
                        id: "monthly",
                        type: .monthly,
                        localizedPrice: "1,99 \u{20AC}",
                        localizedPricePerMonth: "1,99 \u{20AC}"
                    ),
                    SubscriptionPackage(
                        id: "annual",
                        type: .annual,
                        localizedPrice: "9,99 \u{20AC}",
                        localizedPricePerMonth: "0,83 \u{20AC}"
                    )
                ],
                selectedPackage: SubscriptionPackage(
                    id: "annual",
                    type: .annual,
                    localizedPrice: "9,99 \u{20AC}",
                    localizedPricePerMonth: "0,83 \u{20AC}"
                )
            )
        ) {
            PaywallFeature()
        }
    )
}
