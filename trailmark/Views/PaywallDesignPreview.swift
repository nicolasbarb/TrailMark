import SwiftUI

/// Reference design for the PaceMark PRO paywall.
/// Use this as a visual guide when designing in RevenueCat dashboard.
/// This file is NOT used in production — the app uses RevenueCatUI.PaywallView.
///
/// —— PALETTE DARK MODE ——
/// Background principal : #000000
/// Background cards : #1C1C1E
/// Accent orange : #FF9500
/// Texte principal : #FFFFFF
/// Texte secondaire : #8E8E93
/// Texte muted : #48484A
/// Bordure : #38383A
///
/// —— PALETTE LIGHT MODE ——
/// Background principal : #FFFFFF
/// Background cards : #F2F2F7
/// Accent orange : #FF9500
/// Texte principal : #000000
/// Texte secondaire : #8E8E93
/// Texte muted : #C7C7CC
/// Bordure : #C6C6C8
///
/// —— LIENS LÉGAUX ——
/// Politique de confidentialité : https://nicolasbarb.github.io/PaceMark/privacy.html
/// Conditions d'utilisation : https://nicolasbarb.github.io/PaceMark/terms.html

// MARK: - Hex Color Initializer (private to this file)

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

struct PaywallDesignPreview: View {
    @State private var selectedPlan: Plan = .annual
    let mode: Mode

    enum Plan { case annual, monthly }
    enum Mode { case dark, light }

    // MARK: - Couleurs en dur selon le mode

    private var bgPrimary: Color { mode == .dark ? Color(hex: "000000") : Color(hex: "FFFFFF") }
    private var bgCards: Color { mode == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7") }
    private var accent: Color { Color(hex: "FF9500") }
    private var textPrimary: Color { mode == .dark ? Color(hex: "FFFFFF") : Color(hex: "000000") }
    private var textSecondary: Color { Color(hex: "8E8E93") }
    private var textMuted: Color { mode == .dark ? Color(hex: "48484A") : Color(hex: "C7C7CC") }
    private var border: Color { mode == .dark ? Color(hex: "38383A") : Color(hex: "C6C6C8") }

    var body: some View {
        ZStack {
            bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 56)
                        .padding(.horizontal, 28)

                    featuresList
                        .padding(.top, 32)
                        .padding(.horizontal, 28)

                    pricingCards
                        .padding(.top, 32)
                        .padding(.horizontal, 20)

                    ctaButton
                        .padding(.top, 28)
                        .padding(.horizontal, 28)

                    footer
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)

            // —— Bouton fermer ——
            // Icone : SF Symbol "xmark"
            // Taille icone : ~12pt (caption), weight semibold
            // Couleur icone : #8E8E93
            // Fond : cercle ultraThinMaterial, 28x28pt
            // Position : top-right, padding 16pt
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(textSecondary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(16)
                }
                Spacer()
            }
        }
    }

    // MARK: - Header

    // —— "PaceMark" ——
    // Font : SF Mono, ~22pt (title2), Bold
    // Couleur : #FF9500
    //
    // —— Badge "PRO" ——
    // Font : SF Mono, 11pt, Black
    // Couleur texte : #FFFFFF
    // Fond : capsule #FF9500
    // Padding : horizontal 10pt, vertical 4pt
    // Espacement entre "PaceMark" et "PRO" : 8pt
    //
    // —— "Passe au niveau superieur" ——
    // Font : SF Pro Display, ~28pt (title), Bold
    // Couleur : Dark #FFFFFF / Light #000000
    // Alignement : centre, 2 lignes
    //
    // —— Sous-titre "Debloquer tout le potentiel..." ——
    // Font : SF Pro Display, ~15pt (subheadline), Regular
    // Couleur : #8E8E93 (identique dark & light)
    // Alignement : centre, 2 lignes
    //
    // Espacement vertical entre elements du header : 12pt
    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("PaceMark")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(accent)

                Text("PRO")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accent, in: Capsule())
            }

            Text("Passe au niveau\nsup\u{00E9}rieur")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(textPrimary)

            Text("D\u{00E9}bloquer tout le potentiel de PaceMark\npour pr\u{00E9}parer chaque course comme un pro.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(textSecondary)
        }
    }

    // MARK: - Features List

    // —— Container features ——
    // Fond : Dark #1C1C1E / Light #F2F2F7
    // Corner radius : 16pt
    // Padding interne : 20pt
    // Espacement entre chaque feature row : 16pt
    //
    // —— Chaque feature row ——
    // Icone SF Symbol : 17pt (body), #FF9500, frame 28x28pt
    // Titre : SF Pro Display, ~15pt (subheadline), Semibold
    //         Dark #FFFFFF / Light #000000
    // Sous-titre : SF Pro Display, ~12pt (caption), Regular
    //              Dark #48484A / Light #C7C7CC
    // Espacement icone <-> texte : 14pt
    // Espacement titre <-> sous-titre : 2pt
    //
    // —— SF Symbols utilises ——
    // map.fill / mappin.and.ellipse / sparkles / person.fill / arrow.up.circle.fill
    private var featuresList: some View {
        VStack(spacing: 16) {
            featureRow(icon: "map.fill", title: "Parcours illimit\u{00E9}s", subtitle: "Importe autant de GPX que tu veux")
            featureRow(icon: "mappin.and.ellipse", title: "Rep\u{00E8}res illimit\u{00E9}s", subtitle: "Place tous les jalons n\u{00E9}cessaires")
            featureRow(icon: "sparkles", title: "D\u{00E9}tection automatique", subtitle: "Les mont\u{00E9}es et descentes sont analys\u{00E9}es pour toi")
            featureRow(icon: "person.fill", title: "Soutiens un dev ind\u{00E9}pendant", subtitle: "PaceMark est con\u{00E7}u par un passionn\u{00E9} de trail")
            featureRow(icon: "arrow.up.circle.fill", title: "Futures fonctionnalit\u{00E9}s PRO", subtitle: "Acc\u{00E8}s prioritaire aux nouvelles features")
        }
        .padding(20)
        .background(bgCards, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(textMuted)
            }
            Spacer()
        }
    }

    // MARK: - Pricing Cards

    // —— Layout general ——
    // 2 cartes cote a cote, espacement 12pt
    // Padding horizontal du container : 20pt
    //
    // —— Badge "POPULAIRE" (carte annuelle uniquement) ——
    // Font : SF Mono, 9pt, Bold, uppercase
    // Couleur texte : #FFFFFF
    // Fond : capsule #FF9500
    // Padding : horizontal 8pt, vertical 3pt
    //
    // —— Label "Annuel" / "Mensuel" ——
    // Font : SF Pro Display, ~12pt (caption), Medium
    // Couleur : #8E8E93 (identique dark & light)
    //
    // —— Prix "9,99 EUR" / "1,99 EUR" ——
    // Font : SF Mono, ~20pt (title3), Bold
    // Couleur : Dark #FFFFFF / Light #000000
    //
    // —— Detail "0,83 EUR/mois" / "/mois" ——
    // Font : SF Mono, ~11pt (caption2), Regular
    // Couleur si selectionne : #FF9500
    // Couleur sinon : Dark #48484A / Light #C7C7CC
    //
    // —— Carte ——
    // Padding vertical : 16pt
    // Corner radius : 14pt
    // Fond selectionne : #FF9500 a 8% opacite (#FF950014)
    // Fond non selectionne : Dark #1C1C1E / Light #F2F2F7
    // Bordure selectionnee : #FF9500, 2pt
    // Bordure non selectionnee : Dark #38383A / Light #C6C6C8, 1pt
    // Espacement vertical entre elements dans la carte : 8pt
    private var pricingCards: some View {
        HStack(spacing: 12) {
            pricingCard(
                label: "Annuel",
                price: "9,99 \u{20AC}",
                detail: "0,83 \u{20AC}/mois",
                badge: "Populaire",
                isSelected: selectedPlan == .annual,
                plan: .annual
            )
            pricingCard(
                label: "Mensuel",
                price: "1,99 \u{20AC}",
                detail: "/mois",
                badge: nil,
                isSelected: selectedPlan == .monthly,
                plan: .monthly
            )
        }
    }

    private func pricingCard(label: String, price: String, detail: String, badge: String?, isSelected: Bool, plan: Plan) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            VStack(spacing: 8) {
                if let badge {
                    Text(badge.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent, in: Capsule())
                } else {
                    Spacer().frame(height: 19)
                }

                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(textSecondary)

                Text(price)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(textPrimary)

                Text(detail)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(isSelected ? accent : textMuted)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accent.opacity(0.08) : bgCards)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? accent : border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    // —— Bouton principal ——
    // Texte : "Debloquer PRO"
    // Font : SF Pro Display, ~17pt (body), Semibold
    // Couleur texte : #FFFFFF
    // Fond : #FF9500
    // Forme : capsule (full rounded)
    // Hauteur : ~50pt (large)
    // Largeur : pleine largeur (flexible)
    private var ctaButton: some View {
        Button {} label: {
            Text("D\u{00E9}bloquer PRO")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    // —— "Restaurer les achats" ——
    // Font : SF Pro Display, ~12pt (caption), Regular, souligne
    // Couleur : Dark #48484A / Light #C7C7CC
    //
    // —— Texte legal "Paiement securise..." ——
    // Font : SF Pro Display, ~11pt (caption2), Regular
    // Couleur : Dark #48484A / Light #C7C7CC
    // Alignement : centre
    //
    // —— Liens "Conditions d'utilisation" / "Politique de confidentialite" ——
    // Font : SF Pro Display, ~11pt (caption2), Regular
    // Couleur : Dark #48484A / Light #C7C7CC
    // Espacement entre les 2 liens : 16pt
    //
    // Espacement vertical entre elements du footer : 12pt
    private var footer: some View {
        VStack(spacing: 12) {
            Text("Restaurer les achats")
                .underline()
                .font(.caption)
                .foregroundStyle(textMuted)

            Text("Paiement s\u{00E9}curis\u{00E9} via App Store\nAnnulation possible \u{00E0} tout moment")
                .font(.caption2)
                .foregroundStyle(textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Text("Conditions d'utilisation")
                Text("Politique de confidentialit\u{00E9}")
            }
            .font(.caption2)
            .foregroundStyle(textMuted)
        }
    }
}

#Preview("Dark") {
    PaywallDesignPreview(mode: .dark)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    PaywallDesignPreview(mode: .light)
        .preferredColorScheme(.light)
}
