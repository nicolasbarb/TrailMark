//
//  OnboardingCarousel.swift
//  TrailMark
//
//  Adapted from iOS26StyleOnBoarding by Balaji Venkatesh
//

import SwiftUI

struct OnboardingCarousel: View {
    var tint: Color = .orange
    var hideBezels: Bool = false
    var items: [Item]
    var onComplete: () -> ()
    /// View Properties
    @State private var currentIndex: Int = 0
    @State private var scrollIndex: Int = 0  // Index visuel du screenshot (peut différer de currentIndex)
    @State private var screenshotSize: CGSize = .zero

    /// Si zoomScale > 1, le fond noir est visible donc texte clair, sinon texte sombre
    private var isZoomed: Bool { items[currentIndex].zoomScale > 1 }
    private var currentTextColor: Color { isZoomed ? .white : .primary }
    private var currentTextSecondaryColor: Color { isZoomed ? .white.opacity(0.8) : .secondary }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenshotView()
                .compositingGroup()
                .scaleEffect(
                    items[currentIndex].zoomScale,
                    anchor: items[currentIndex].zoomAnchor
                )
                .padding(.top, 35)
                .padding(.horizontal, 30)
                .padding(.bottom, 220)

            VStack(spacing: 10) {
                TextContentView()
                IndicatorView()
                ContinueButton()
            }
            .padding(.top, 20)
            .padding(.horizontal, 15)
            .frame(height: 210)
            .background {
                VariableGlassBlur(15)
            }

            BackButton()
        }
        .preferredColorScheme(.light)
    }

    /// Screenshot View
    @ViewBuilder
    func ScreenshotView() -> some View {
        let shape = ConcentricRectangle(corners: .concentric, isUniform: true)

        GeometryReader {
            let size = $0.size

            Rectangle()
                .fill(.black)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]

                        Group {
                            if let screenshot = item.screenshot {
                                Image(uiImage: screenshot)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .onGeometryChange(for: CGSize.self) {
                                        $0.size
                                    } action: { newValue in
                                        screenshotSize = newValue
                                    }
                                    .clipShape(shape)
                            } else {
                                Rectangle()
                                    .fill(.black)
                            }
                        }
                        .frame(width: size.width, height: size.height)
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
        .clipShape(shape)
        .overlay {
            if screenshotSize != .zero && !hideBezels {
                /// Device Frame UI
                ZStack {
                    shape
                        .stroke(.white, lineWidth: 6)

                    shape
                        .stroke(.black, lineWidth: 4)

                    shape
                        .stroke(.black, lineWidth: 6)
                        .padding(4)
                }
                .padding(-7)
            }
        }
        .frame(
            maxWidth: screenshotSize.width == 0 ? nil : screenshotSize.width,
            maxHeight: screenshotSize.height == 0 ? nil : screenshotSize.height
        )
        .containerShape(RoundedRectangle(cornerRadius: deviceCornerRadius))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Text Content View
    @ViewBuilder
    func TextContentView() -> some View {
        GeometryReader {
            let size = $0.size

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        let isActive = currentIndex == index

                        VStack(spacing: 6) {
                            let itemIsZoomed = item.zoomScale > 1
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .foregroundStyle(currentTextColor)
//                                .foregroundStyle(itemIsZoomed ? .white : .black)

                            Text(item.subtitle)
                                .font(.callout)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(currentTextSecondaryColor)
//                                .foregroundStyle(itemIsZoomed ? .white.opacity(0.8) : .black.opacity(0.6))
                        }
                        .frame(width: size.width)
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
    }

    /// Indicator View
    @ViewBuilder
    func IndicatorView() -> some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                let isActive: Bool = currentIndex == index

                Capsule()
                    .fill(currentTextColor.opacity(isActive ? 1 : 0.4))
                    .frame(width: isActive ? 25 : 6, height: 6)
            }
        }
        .padding(.bottom, 5)
    }

    /// Bottom Continue Button
    @ViewBuilder
    func ContinueButton() -> some View {
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
            Text(currentIndex == items.count - 1 ? "C'est parti !" : "Continuer")
                .fontWeight(.medium)
                .contentTransition(.numericText())
                .padding(.vertical, 6)
        }
        .tint(tint)
        .buttonStyle(.glassProminent)
        .buttonSizing(.flexible)
        .padding(.horizontal, 30)
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
        let tint: Color = .black.opacity(0.5)
        Rectangle()
            .fill(tint)
            .glassEffect(.clear, in: .rect)
            .blur(radius: radius)
            .padding([.horizontal, .bottom], -radius * 2)
            .padding(.top, -radius / 2)
            .opacity(items[currentIndex].zoomScale > 1 ? 1 : 0)
            .ignoresSafeArea()
    }

    var deviceCornerRadius: CGFloat {
        if let imageSize = items.first?.screenshot?.size {
            let ratio = screenshotSize.height / imageSize.height
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
                title: "Place tes jalons",
                subtitle: "Marque les moments clés :\nmontées, ravitos, dangers...",
                screenshot: UIImage(named: "jalonScreenshot"),
                zoomScale: 1.3,
                zoomAnchor: .init(x: 0.5, y: 0.8)
            ),
            .init(
                id: 4,
                title: "Laisse-toi guider",
                subtitle: "Reçois des annonces vocales\nà chaque jalon pendant ta course.",
                screenshot: UIImage(named: "playScreenshot")
            )
        ]
    ) {
        print("Completed")
    }
}
