import SwiftUI
import ComposableArchitecture
import RevenueCatUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        ZStack {
            switch store.currentPhase {
            case .carousel:
                OnboardingCarousel(
                    tint: .orange,
                    hideBezels: false,
                    items: [
                        .init(
                            id: 0,
                            title: "Bienvenue sur TrailMark",
                            subtitle: "Ton guide vocal pour\nle trail running.",
                            screenshot: UIImage(named: "listScreenshot")
                        ),
                        .init(
                            id: 1,
                            title: "Importe ta trace GPX",
                            subtitle: "Charge ton parcours depuis\nun fichier GPX.",
                            screenshot: UIImage(named: "gpxScreenshot")
                        ),
                        .init(
                            id: 2,
                            title: "Analyse le profil",
                            subtitle: "Visualise la trace de ton gpx et\nles points clés du parcours.",
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.3,
                            zoomAnchor: .init(x: 0.5, y: 0.0)
                        ),
                        .init(
                            id: 3,
                            title: "Place tes jalons",
                            subtitle: "Analyse le dénivelé et marque les moments clés :\nmontées, descentes, ravitos, dangers...",
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.5,
                            zoomAnchor: .init(x: 0.5, y: 1.2)
                        ),
                        .init(
                            id: 4,
                            title: "Laisse-toi guider",
                            subtitle: "Reçois des annonces vocales\nà chaque jalon pendant ta course.",
                            screenshot: UIImage(named: "playScreenshot")
                        )
                    ]
                ) {
                    store.send(.carouselCompleted)
                }
                .transition(.opacity)

            case .location:
                locationPage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .paywall:
                paywallPage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.currentPhase)
    }

    // MARK: - Location Page

    private var locationPage: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(TM.accent.opacity(0.15))
                            .frame(width: 120, height: 120)

                        Image(systemName: "location.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(TM.accent)
                    }

                    VStack(spacing: 12) {
                        Text("Autorisation GPS")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        Text("TrailMark a besoin d'accéder à ta position pour te guider vocalement pendant ta course, même en arrière-plan.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    if store.locationAuthorizationStatus == .authorized {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(TM.success)
                            Text("Localisation autorisée")
                                .foregroundStyle(TM.success)
                        }
                        .font(.subheadline.weight(.medium))
                    } else if store.locationAuthorizationStatus == .denied {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(TM.danger)
                            Text("Localisation refusée")
                                .foregroundStyle(TM.danger)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 16) {
                    if store.locationAuthorizationStatus == .notDetermined {
                        Button {
                            store.send(.requestLocationAuthorization)
                        } label: {
                            Text("Autoriser la localisation")
                                .fontWeight(.medium)
                                .padding(.vertical, 6)
                        }
                        .tint(.orange)
                        .buttonStyle(.glassProminent)
                        .buttonSizing(.flexible)
                        .padding(.horizontal, 45)
                    } else {
                        Button {
                            store.send(.locationCompleted)
                        } label: {
                            Text("Continuer")
                                .fontWeight(.medium)
                                .padding(.vertical, 6)
                        }
                        .tint(.orange)
                        .buttonStyle(.glassProminent)
                        .buttonSizing(.flexible)
                        .padding(.horizontal, 45)
                    }

                    if store.locationAuthorizationStatus == .notDetermined {
                        Button {
                            store.send(.locationCompleted)
                        } label: {
                            Text("Plus tard")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Paywall Page

    private var paywallPage: some View {
        VStack(spacing: 0) {
            RevenueCatUI.PaywallView(displayCloseButton: false)
                .onPurchaseCompleted { _ in
                    store.send(.paywallCompleted)
                }
                .onRestoreCompleted { _ in
                    store.send(.paywallCompleted)
                }

            Button {
                store.send(.skipPaywall)
            } label: {
                Text("Continuer avec la version gratuite")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, 30)
        }
        .background(Color.black)
    }
}

#Preview("Carousel") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentPhase: .carousel)) {
            OnboardingFeature()
        }
    )
}

#Preview("Location") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentPhase: .location)) {
            OnboardingFeature()
        }
    )
}

#Preview("Location - Autorisée") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(
            currentPhase: .location,
            locationAuthorizationStatus: .authorized
        )) {
            OnboardingFeature()
        }
    )
}

#Preview("Location - Refusée") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(
            currentPhase: .location,
            locationAuthorizationStatus: .denied
        )) {
            OnboardingFeature()
        }
    )
}

#Preview("Paywall") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentPhase: .paywall)) {
            OnboardingFeature()
        }
    )
}
