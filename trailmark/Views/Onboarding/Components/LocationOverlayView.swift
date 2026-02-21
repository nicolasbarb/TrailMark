//
//  LocationOverlayView.swift
//  TrailMark
//

import SwiftUI

struct LocationOverlayView: View {
    let isVisible: Bool
    let animatePin: Bool
    var isSuccess: Bool = false

    var body: some View {
        ZStack {
            // Dim overlay
            Rectangle()
                .fill(.black.opacity(isVisible ? 0.5 : 0))

            // Pulse and pin
            if isVisible {
                ZStack {
                    PulseRingView(tint: isSuccess ? .green : .white, size: 150)
                        .transition(.blurReplace)
                        .animation(.smooth(duration: 0.5), value: isSuccess)

                    Image(systemName: isSuccess ? "checkmark.circle" : "mappin")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle((isSuccess ? Color.green : Color.white).shadow(.drop(radius: 5)))
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                        .rotation3DEffect(
                            .init(degrees: animatePin && !isSuccess ? -40 : 0),
                            axis: (x: 1, y: 0, z: 0)
                        )
                        .scaleEffect(animatePin ? 1 : 10)
                        .opacity(animatePin ? 1 : 0)
                        .blur(radius: animatePin ? 0 : 5)
                        .offset(y: isSuccess ? 0 : -12)
                        .animation(.smooth(duration: 0.5), value: isSuccess)
                }
            }
        }
        .clipShape(ConcentricRectangle(corners: .concentric, isUniform: true))
    }
}

// MARK: - Pulse Ring View

struct PulseRingView: View {
    var tint: Color
    var size: CGFloat

    @State private var animate: [Bool] = [false, false, false]
    @State private var showRings: Bool = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            if showRings {
                ZStack {
                    RingView(index: 0)
                    RingView(index: 1)
                    RingView(index: 2)
                }
                .onAppear {
                    for index in 0..<animate.count {
                        let delay = Double(index) * 0.2
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false).delay(delay)) {
                            animate[index] = true
                        }
                    }
                }
                .onDisappear {
                    animate = [false, false, false]
                }
            }
        }
        .onChange(of: phase, initial: true) { _, newValue in
            showRings = newValue != .background
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func RingView(index: Int) -> some View {
        Circle()
            .fill(tint)
            .opacity(animate[index] ? 0 : 0.4)
            .scaleEffect(animate[index] ? 2 : 0)
    }
}

#Preview("Location Success Animation") {
    @Previewable @State var isSuccess = false

    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
            RoundedRectangle(cornerRadius: 50)
                .fill(.gray.opacity(0.3))
                .frame(width: 250, height: 500)
                .overlay {
                    LocationOverlayView(
                        isVisible: true,
                        animatePin: true,
                        isSuccess: isSuccess
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 50))

            Button(isSuccess ? "Reset" : "Simulate Success") {
                withAnimation(.smooth) {
                    isSuccess.toggle()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(isSuccess ? .red : .green)
        }
    }
}
