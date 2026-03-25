import SwiftUI
import ComposableArchitecture
import CoreLocation

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingStore>

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
                            title: String(localized: "onboarding.slide1.title"),
                            subtitle: String(localized: "onboarding.slide1.subtitle"),
                            screenshot: UIImage(named: "gpxScreenshot")
                        ),
                        .init(
                            id: 1,
                            title: String(localized: "onboarding.slide2.title"),
                            subtitle: String(localized: "onboarding.slide2.subtitle"),
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.3,
                            zoomAnchor: .init(x: 0.5, y: 0.0)
                        ),
                        .init(
                            id: 2,
                            title: String(localized: "onboarding.slide3.title"),
                            subtitle: String(localized: "onboarding.slide3.subtitle"),
                            screenshot: UIImage(named: "editScreenshot"),
                            zoomScale: 1.5,
                            zoomAnchor: .init(x: 0.5, y: 1.2),
                            sameScreenshotAsPrevious: true
                        ),
                        .init(
                            id: 3,
                            title: String(localized: "onboarding.slide4.title"),
                            subtitle: String(localized: "onboarding.slide4.subtitle"),
                            screenshot: UIImage(named: "playScreenshot")
                        ),
                        .init(
                            id: 4,
                            title: String(localized: "onboarding.slide5.title"),
                            subtitle: String(localized: "onboarding.slide5.subtitle"),
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

                Text("onboarding.intro.subtitle")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Haptic.medium.trigger()
                onContinue()
            } label: {
                Text("onboarding.intro.startButton")
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
        store: Store(initialState: OnboardingStore.State(currentPhase: .intro)) {
            OnboardingStore()
        }
    )
}

#Preview("Carousel") {
    OnboardingView(
        store: Store(initialState: OnboardingStore.State(currentPhase: .carousel)) {
            OnboardingStore()
        }
    )
}
