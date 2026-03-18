import SwiftUI
import ComposableArchitecture
import CoreLocation

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        ZStack {
            switch store.currentPhase {
            case .intro:
                IntroView {
                    store.send(.introCompleted)
                }
                .transition(.opacity)

            case .carousel:
                OnboardingCarousel(
                    tint: .orange,
                    hideBezels: false,
                    items: [
                        .init(
                            id: 0,
                            title: "Importe ton parcours",
                            subtitle: "Un fichier GPX, et PaceMark\nanalyse tout automatiquement.",
                            screenshot: UIImage(named: "gpxScreenshot")
                        ),
                        .init(
                            id: 1,
                            title: "Prépare ta stratégie",
                            subtitle: "Visualise le profil altimétrique\net les segments clés de ta course.",
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.3,
                            zoomAnchor: .init(x: 0.5, y: 0.0)
                        ),
                        .init(
                            id: 2,
                            title: "Place tes repères",
                            subtitle: "Chaque segment a son instruction.\nMontées, descentes, ravitos, dangers.",
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.5,
                            zoomAnchor: .init(x: 0.5, y: 1.2),
                            sameScreenshotAsPrevious: true
                        ),
                        .init(
                            id: 3,
                            title: "Cours sans écran",
                            subtitle: "Téléphone en poche. PaceMark t'annonce\nchaque repère au bon moment.",
                            screenshot: UIImage(named: "playScreenshot")
                        ),
                        .init(
                            id: 4,
                            title: "Autorisation GPS",
                            subtitle: "PaceMark a besoin du GPS pour\ndéclencher les annonces vocales.",
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
                    onLocationSkipped: {
                        store.send(.locationSkipped)
                    },
                    locationStatus: store.locationStatus,
                    isLocationSuccess: store.isLocationSuccess,
                    isLocationDenied: store.isLocationDenied
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: store.currentPhase)
    }
}

// MARK: - Intro View

private struct IntroView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 32))

            VStack(spacing: 12) {
                Text("PaceMark")
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.accent)

                Text("Prépare ta course comme un pro.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Haptic.medium.trigger()
                onContinue()
            } label: {
                Text("Commencer")
                    .fontWeight(.medium)
                    .padding(.vertical, 6)
            }
            .primaryButton(width: .flexible)
        }
        .padding(16)
    }
}

#Preview("Intro") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentPhase: .intro)) {
            OnboardingFeature()
        }
    )
}

#Preview("Carousel") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentPhase: .carousel)) {
            OnboardingFeature()
        }
    )
}
