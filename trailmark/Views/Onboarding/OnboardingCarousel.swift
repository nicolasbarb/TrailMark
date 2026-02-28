//
//  OnboardingCarousel.swift
//  TrailMark
//
//  Adapted from iOS26StyleOnBoarding by Balaji Venkatesh
//

import SwiftUI
import CoreLocation

struct OnboardingCarousel: View {
    var tint: Color = .orange
    var hideBezels: Bool = false
    var items: [Item]
    var onComplete: () -> Void
    var onRequestLocation: (() -> Void)? = nil
    var onLocationSkipped: (() -> Void)? = nil
    var locationStatus: CLAuthorizationStatus = .notDetermined
    var isLocationSuccess: Bool = false
    var isLocationDenied: Bool = false
    /// View Properties
    @State private var currentIndex: Int = 0
    @State private var scrollIndex: Int = 0  // Index visuel du screenshot (peut différer de currentIndex)
    @State private var screenshotSize: CGSize = .zero
    @State private var showLocationOverlay: Bool = false
    @State private var animatePin: Bool = false
    @State private var dragOffset: CGFloat = 0

    /// Si zoomScale > 1, le fond noir est visible donc texte clair
    private var isZoomed: Bool { items[currentIndex].zoomScale > 1 }
    private var currentTextColor: Color { isZoomed ? .white : .primary }
    private var currentTextSecondaryColor: Color { isZoomed ? .white.opacity(0.8) : .secondary }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                ScreenshotView()
                    .compositingGroup()
                    .scaleEffect(
                        items[currentIndex].zoomScale,
                        anchor: items[currentIndex].zoomAnchor
                    )
                    .layoutPriority(1)
                Spacer()
                
                VStack(spacing: 12) {
                    TextContentView()
                    Spacer()
                    if !items[currentIndex].isLocationStep {
                        IndicatorView()
                            .padding(.bottom, 8)
                    }
                    ContinueButton()
                        .padding(.bottom, 16)
                }
                .background {
                    VariableGlassBlur(15)
                }
            }
            .padding(.horizontal, 16)

            if !items[currentIndex].isLocationStep {
                BackButton()
            }
        }
        .contentShape(Rectangle())
        .gesture(items[currentIndex].isLocationStep ? nil : swipeGesture)
    }

    /// Swipe gesture for navigation
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                let horizontalAmount = value.translation.width

                withAnimation(animation) {
                    if horizontalAmount < -threshold {
                        // Swipe left → next
                        goToNext()
                    } else if horizontalAmount > threshold {
                        // Swipe right → previous
                        goToPrevious()
                    }
                    dragOffset = 0
                }
            }
    }

    private func goToNext() {
        guard currentIndex < items.count - 1 else {
            // On last item, complete if swiping forward
            if currentIndex == items.count - 1 {
                onComplete()
            }
            return
        }

        let nextIndex = currentIndex + 1
        let nextItem = items[nextIndex]

        currentIndex = nextIndex
        if !nextItem.sameScreenshotAsPrevious {
            scrollIndex = nextIndex
        }
    }

    private func goToPrevious() {
        guard currentIndex > 0 else { return }

        let currentItem = items[currentIndex]
        let prevIndex = currentIndex - 1

        currentIndex = prevIndex
        if !currentItem.sameScreenshotAsPrevious {
            scrollIndex = prevIndex
        }
    }

    /// Screenshot View
    @ViewBuilder
    func ScreenshotView() -> some View {
        let shape = ConcentricRectangle(corners: .concentric, isUniform: true)
        // Ratio d'un iPhone (environ 19.5:9 pour les modèles récents)
        let screenshotAspectRatio: CGFloat = 19.5 / 9

        GeometryReader { proxy in
            // Largeur cible = 65% de l'écran
            let targetWidth = proxy.size.width * 0.65
            let targetHeight = targetWidth * screenshotAspectRatio

            ZStack {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(items.indices, id: \.self) { index in
                            let item = items[index]

                            Group {
                                if let screenshot = item.screenshot {
                                    Image(uiImage: screenshot)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: targetWidth, height: targetHeight)
                                        .clipShape(shape)
                                        .onGeometryChange(for: CGSize.self) {
                                            $0.size
                                        } action: { newValue in
                                            screenshotSize = newValue
                                        }
                                } else {
                                    AppIconPlaceholderView(width: targetWidth, height: targetHeight)
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollDisabled(true)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .scrollPosition(id: .init(get: {
                    return scrollIndex
                }, set: { _ in }))
            }
            .frame(width: targetWidth, height: targetHeight)
            .overlay {
                // Device frame seulement si l'item courant a un screenshot
                if !hideBezels && items[currentIndex].screenshot != nil {
                    DeviceFrameView()
                }
            }
            .overlay {
                // Location permission overlay (pin + pulse + dim)
                if items[currentIndex].isLocationStep {
                    LocationOverlayView(
                        isVisible: showLocationOverlay,
                        animatePin: animatePin,
                        isSuccess: isLocationSuccess,
                        isDenied: isLocationDenied
                    )
                }
            }
            .containerShape(RoundedRectangle(cornerRadius: deviceCornerRadius))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Contraindre la hauteur du GeometryReader pour qu'il ne prenne que l'espace nécessaire
        // Ratio ajusté pour inclure la bordure du device frame (environ 14pt en haut et en bas)
        .aspectRatio(9.0 / (0.65 * 19.5) * 0.95, contentMode: .fit)
        .onChange(of: currentIndex) { _, newIndex in
            // Animate location overlay when entering/leaving location step
            if items[newIndex].isLocationStep {
                Task {
                    try? await Task.sleep(for: .seconds(0.3))
                    withAnimation(.smooth(duration: 0.45)) {
                        showLocationOverlay = true
                    }
                    // Animate pin after overlay appears
                    try? await Task.sleep(for: .seconds(0.15))
                    withAnimation(.smooth(duration: 0.45)) {
                        animatePin = true
                    }
                }
            } else {
                showLocationOverlay = false
                animatePin = false
            }
        }
    }

    /// Text Content View
    @ViewBuilder
    func TextContentView() -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    let isActive = currentIndex == index

                    VStack(spacing: 6) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(currentTextColor)

                        Text(item.subtitle)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(currentTextSecondaryColor)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .containerRelativeFrame(.horizontal)
                    .compositingGroup()
                    /// Only The current Item is visible others are blurred out!
                    .blur(radius: isActive ? 0 : 30)
                    .opacity(isActive ? 1 : 0)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(true)
        .scrollTargetBehavior(.paging)
        .scrollClipDisabled()
        .scrollPosition(id: .init(get: {
            return currentIndex
        }, set: { _ in }))
    }

    /// Indicator View
    @ViewBuilder
    func IndicatorView() -> some View {
        OnboardingIndicatorView(
            itemCount: items.count - 1,
            currentIndex: currentIndex,
            textColor: currentTextColor
        )
    }

    /// Bottom Continue Button
    @ViewBuilder
    func ContinueButton() -> some View {
        let currentItem = items[currentIndex]

        if currentItem.isLocationStep {
            // Location permission buttons
            LocationButtons()
                .animation(.smooth(duration: 0.4), value: isLocationSuccess)
        } else {
            // Regular continue button + skip
            VStack(spacing: 12) {
                Button {
                    if currentIndex == items.count - 1 {
                        onComplete()
                    }

                    let nextIndex = min(currentIndex + 1, items.count - 1)
                    let nextItem = items[nextIndex]

                    withAnimation(animation) {
                        currentIndex = nextIndex
                        // Ne pas scroller si le prochain item utilise le même screenshot
                        if !nextItem.sameScreenshotAsPrevious {
                            scrollIndex = nextIndex
                        }
                    }
                } label: {
                    Text("Continuer")
                        .fontWeight(.medium)
                        .contentTransition(.numericText())
                        .padding(.vertical, 6)
                }
                .primaryButton(width: .flexible)

                Button {
                    skipToLocationStep()
                } label: {
                    Text("Passer")
                }
                .tertiaryButton(tint: currentTextColor)
            }
        }
    }

    private func skipToLocationStep() {
        // Find the location step index
        guard let locationIndex = items.firstIndex(where: { $0.isLocationStep }) else { return }

        withAnimation(animation) {
            currentIndex = locationIndex
            scrollIndex = locationIndex
        }
    }

    /// Location permission buttons
    @ViewBuilder
    func LocationButtons() -> some View {
        let isAuthorized = locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways

        if !isLocationSuccess && !isLocationDenied {
            Button {
                print("[Carousel] Location button tapped, isAuthorized: \(isAuthorized)")
                if isAuthorized {
                    advanceFromLocationStep()
                } else {
                    print("[Carousel] Calling onRequestLocation")
                    onRequestLocation?()
                }
            } label: {
                Text("Continuer")
                    .fontWeight(.medium)
                    .contentTransition(.numericText())
                    .padding(.vertical, 6)
            }
            .primaryButton(width: .flexible)
            .animation(.snappy, value: locationStatus)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    private func advanceFromLocationStep() {
        if currentIndex == items.count - 1 {
            onComplete()
        }

        let nextIndex = min(currentIndex + 1, items.count - 1)
        let nextItem = items[nextIndex]

        withAnimation(animation) {
            currentIndex = nextIndex
            if !nextItem.sameScreenshotAsPrevious {
                scrollIndex = nextIndex
            }
        }
    }

    /// Back Button
    @ViewBuilder
    func BackButton() -> some View {
        Button {
            let currentItem = items[currentIndex]
            let prevIndex = max(currentIndex - 1, 0)

            withAnimation(animation) {
                currentIndex = prevIndex
                // Ne pas scroller si l'item actuel utilise le même screenshot que le précédent
                if !currentItem.sameScreenshotAsPrevious {
                    scrollIndex = prevIndex
                }
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3)
                .frame(width: 20, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 15)
        .padding(.top, 5)
        .opacity(currentIndex > 0 ? 1 : 0)
    }

    /// Variable Glass Effect Blur
    @ViewBuilder
    func VariableGlassBlur(_ radius: CGFloat) -> some View {
        Rectangle()
            .fill(.black.opacity(0.5))
            .glassEffect(.clear, in: .rect(cornerRadius: 20))
            .padding([.horizontal, .bottom], -radius * 2)
            .padding(.top, -radius / 0.5)
            .opacity(items[currentIndex].zoomScale > 1 ? 1 : 0)
            .ignoresSafeArea()
    }

    var deviceCornerRadius: CGFloat {
        // Chercher le premier item avec un screenshot
        if let firstScreenshot = items.first(where: { $0.screenshot != nil })?.screenshot {
            let ratio = screenshotSize.height / firstScreenshot.size.height
            let actualCornerRadius: CGFloat = 180
            return actualCornerRadius * ratio
        }

        return 0
    }

    struct Item: Identifiable {
        var id: Int
        var title: String
        var subtitle: String
        var screenshot: UIImage?
        var zoomScale: CGFloat = 1
        var zoomAnchor: UnitPoint = .center
        /// Si true, pas d'animation de scroll horizontal, seulement le zoom/anchor change
        var sameScreenshotAsPrevious: Bool = false
        /// Si true, affiche l'UI de permission de localisation (pin + pulse + boutons spéciaux)
        var isLocationStep: Bool = false
    }

    var animation: Animation {
        .interpolatingSpring(duration: 0.65, bounce: 0, initialVelocity: 0)
    }
}

#Preview("Carousel - TrailMark") {
    OnboardingCarousel(
        tint: .accentColor,
        hideBezels: false,
        items: [
            .init(
                id: 2,
                title: "Analyse le profil",
                subtitle: "Visualise le dénivelé et\nles points clés du parcours.",
                screenshot: UIImage(named: "editScreenshot"),
                zoomScale: 1.2,
                zoomAnchor: .init(x: 0.5, y: 0.7,)
            ),
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
                subtitle: "Visualise le dénivelé et\nles points clés du parcours.",
                screenshot: UIImage(named: "editScreenshot"),
                zoomScale: 1.2,
                zoomAnchor: .init(x: 0.5, y: 0.7,)
            ),
            .init(
                id: 3,
                title: "Place tes repères",
                subtitle: "Marque les moments clés :\nmontées, ravitos, dangers...",
                screenshot: UIImage(named: "jalonScreenshot"),
                zoomScale: 1.3,
                zoomAnchor: .init(x: 0.5, y: 0.8)
            ),
            .init(
                id: 4,
                title: "Laisse-toi guider",
                subtitle: "Reçois des annonces vocales\nà chaque repère pendant ta course.",
                screenshot: UIImage(named: "playScreenshot")
            )
        ]
    ) {
        print("Completed")
    }
}
