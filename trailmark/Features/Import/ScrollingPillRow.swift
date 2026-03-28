import SwiftUI

// MARK: - Scrolling Pill Row

struct ScrollingPillRow: View {
    let names: [String]
    let reversed: Bool
    let duration: Double
    let startOffset: CGFloat
    var exiting: Bool = false

    @State private var contentWidth: CGFloat = 0
    @State private var exitStartTime: Date?
    @State private var exitBaseOffset: CGFloat = 0

    private let exitDuration: Double = 1.5

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                HStack(spacing: 8) {
                    pillContent
                    pillContent
                }
                .fixedSize()
                .offset(x: computeShift(at: timeline.date, containerWidth: geo.size.width))
            }
        }
        .frame(height: 40)
        .clipped()
        .onChange(of: exiting) { _, isExiting in
            if isExiting {
                let time = Date().timeIntervalSinceReferenceDate
                let progress = CGFloat(time.truncatingRemainder(dividingBy: duration)) / CGFloat(duration)
                exitBaseOffset = reversed
                    ? -contentWidth + progress * contentWidth + startOffset
                    : startOffset - progress * contentWidth
                exitStartTime = Date()
            } else {
                exitStartTime = nil
            }
        }
    }

    private func computeShift(at date: Date, containerWidth: CGFloat) -> CGFloat {
        if let exitStart = exitStartTime {
            let elapsed = CGFloat(date.timeIntervalSince(exitStart))
            let progress = min(elapsed / CGFloat(exitDuration), 1.0)
            // Exponential ease-in: very slow at start, very fast at end
            let eased = pow(progress, 5)
            let exitDistance = (containerWidth + contentWidth * 2) * (reversed ? 1 : -1)
            return exitBaseOffset + eased * exitDistance
        } else {
            let time = date.timeIntervalSinceReferenceDate
            let progress = CGFloat(time.truncatingRemainder(dividingBy: duration)) / CGFloat(duration)
            return reversed
                ? -contentWidth + progress * contentWidth + startOffset
                : startOffset - progress * contentWidth
        }
    }

    private var pillContent: some View {
        HStack(spacing: 8) {
            ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(TM.textPrimary.opacity(0.2))
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(TM.accent.opacity(0.05), in: Capsule())
                    .overlay(Capsule().strokeBorder(TM.accent.opacity(0.08), lineWidth: 1))
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    contentWidth = geo.size.width + 8
                }
            }
        )
    }
}
