import SwiftUI
import ComposableArchitecture
import RevenueCatUI
import CoreLocation

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
                            title: "TrailMark",
                            subtitle: "Prépare ta course.\nOptimise ta performance."
                        ),
                        .init(
                            id: 1,
                            title: "Bienvenue sur TrailMark",
                            subtitle: "Ton guide vocal pour\nle trail running.",
                            screenshot: UIImage(named: "listScreenshot")
                        ),
                        .init(
                            id: 2,
                            title: "Importe ta trace GPX",
                            subtitle: "Charge ton parcours depuis\nun fichier GPX.",
                            screenshot: UIImage(named: "gpxScreenshot")
                        ),
                        .init(
                            id: 3,
                            title: "Analyse le profil",
                            subtitle: "Visualise la trace de ton gpx et\nles points clés du parcours.",
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.3,
                            zoomAnchor: .init(x: 0.5, y: 0.0)
                        ),
                        .init(
                            id: 4,
                            title: "Place tes jalons",
                            subtitle: "Analyse le dénivelé et marque les moments clés :\nmontées, descentes, ravitos, dangers...",
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.5,
                            zoomAnchor: .init(x: 0.5, y: 1.2),
                            sameScreenshotAsPrevious: true
                        ),
                        .init(
                            id: 5,
                            title: "Laisse-toi guider",
                            subtitle: "Reçois des annonces vocales\nà chaque jalon pendant ta course.",
                            screenshot: UIImage(named: "playScreenshot")
                        ),
                        .init(
                            id: 6,
                            title: "Autorisation GPS",
                            subtitle: "Autorise TrailMark à accéder à ta\nposition pour te guider vocalement.",
                            screenshot: UIImage(named: "mapScreenshot"),
                            isLocationStep: true
                        )
                    ],
                    onComplete: {
                        store.send(.carouselCompleted)
                    },
                    onRequestLocation: {
                        store.send(.requestLocationAuthorization)
                    },
                    onOpenSettings: {
                        store.send(.openSettings)
                    },
                    onLocationSkipped: {
                        store.send(.locationSkipped)
                    },
                    locationStatus: store.locationStatus
                )
                .transition(.opacity)

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

#Preview("Paywall") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentPhase: .paywall)) {
            OnboardingFeature()
        }
    )
}
