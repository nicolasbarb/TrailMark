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
                            title: "Tous tes parcours réunis",
                            subtitle: "Centralise tous tes parcours\net accède-y en un instant.",
                            screenshot: UIImage(named: "listScreenshot")
                        ),
                        .init(
                            id: 1,
                            title: "Importe tes traces GPX",
                            subtitle: "Depuis tes fichiers, mails\nou apps de trace.",
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
                            title: "Place tes repères",
                            subtitle: "Marque les moments clés :\nmontées, descentes, ravitos, dangers...",
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.5,
                            zoomAnchor: .init(x: 0.5, y: 1.2),
                            sameScreenshotAsPrevious: true
                        ),
                        .init(
                            id: 4,
                            title: "Laisse-toi guider",
                            subtitle: "Reçois des annonces vocales\nà chaque repère pendant ta course.",
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
                Text("TrailMark")
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.accent)

                Text("Bienvenue sur TrailMark,\nPrépare ta course. Optimise ta performance.")
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
