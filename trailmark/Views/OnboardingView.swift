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
                            zoomAnchor: .init(x: 0.5, y: 1.2),
                            sameScreenshotAsPrevious: true
                        ),
                        .init(
                            id: 4,
                            title: "Laisse-toi guider",
                            subtitle: "Reçois des annonces vocales\nà chaque jalon pendant ta course.",
                            screenshot: UIImage(named: "playScreenshot")
                        ),
                        .init(
                            id: 5,
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
                    onLocationSkipped: {
                        store.send(.locationSkipped)
                    },
                    locationStatus: store.locationStatus
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
                Text("TrailMark")
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.accent)

                Text("Prépare ta course.\nOptimise ta performance.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Commencer")
                    .fontWeight(.medium)
                    .padding(.vertical, 6)
            }
            .tint(.orange)
            .buttonStyle(.glassProminent)
            .buttonSizing(.flexible)
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
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
