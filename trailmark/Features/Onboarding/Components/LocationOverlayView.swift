//
//  LocationOverlayView.swift
//  TrailMark
//

import SwiftUI

struct LocationOverlayView: View {
    let isVisible: Bool
    let animatePin: Bool
    var isSuccess: Bool = false
    var isDenied: Bool = false

    private var hasResult: Bool { isSuccess || isDenied }

    private var resultSymbol: String {
        if isSuccess { return "checkmark.circle" }
        if isDenied { return "xmark.circle" }
        return "mappin"
    }

    private var resultColor: Color {
        if isSuccess { return .green }
        if isDenied { return .red }
        return .white
    }

    var body: some View {
        ZStack {
            // Dim overlay
            Rectangle()
                .fill(.black.opacity(isVisible ? 0.5 : 0))

            // Pulse and pin
            if isVisible {
                ZStack {
                    PulseRingView(tint: resultColor, size: 150)
                        .transition(.blurReplace)
                        .animation(.smooth(duration: 0.5), value: hasResult)

                    Image(systemName: resultSymbol)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(resultColor.shadow(.drop(radius: 5)))
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                        .rotation3DEffect(
                            .init(degrees: animatePin && !hasResult ? -40 : 0),
                            axis: (x: 1, y: 0, z: 0)
                        )
                        .scaleEffect(animatePin ? 1 : 10)
                        .opacity(animatePin ? 1 : 0)
                        .blur(radius: animatePin ? 0 : 5)
                        .offset(y: hasResult ? 0 : -12)
                        .animation(.smooth(duration: 0.5), value: hasResult)
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

#Preview("Location Animation") {
    @Previewable @State var isSuccess = false
    @Previewable @State var isDenied = false

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
                        isSuccess: isSuccess,
                        isDenied: isDenied
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 50))

            HStack(spacing: 16) {
                Button("Success") {
                    withAnimation(.smooth) {
                        isSuccess = true
                        isDenied = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Denied") {
                    withAnimation(.smooth) {
                        isDenied = true
                        isSuccess = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Reset") {
                    withAnimation(.smooth) {
                        isSuccess = false
                        isDenied = false
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
