import SwiftUI

// MARK: - Real Profile Drawing Animation

struct RealProfileDrawingAnimation: View {
    let trackPoints: [TrackPoint]
    let onFinished: () -> Void

    private let animationDuration: Double = 3.5
    @State private var startTime: Date?
    @State private var hasFinished = false
    var restartToken: UUID = UUID()

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = currentProgress(at: timeline.date)

            Canvas { context, size in
                drawRealProfile(context: context, size: size, progress: progress)
            }
            .task(id: progress >= 1.0) {
                if progress >= 1.0 && !hasFinished {
                    hasFinished = true
                    onFinished()
                }
            }
        }
        .onAppear {
            startTime = Date()
            hasFinished = false
        }
        .onChange(of: restartToken) {
            startTime = Date()
            hasFinished = false
        }
    }

    private func currentProgress(at date: Date) -> CGFloat {
        guard let start = startTime else { return 0 }
        let elapsed = date.timeIntervalSince(start)
        return min(CGFloat(elapsed / animationDuration), 1.0)
    }

    private func drawRealProfile(context: GraphicsContext, size: CGSize, progress: CGFloat) {
        guard trackPoints.count >= 2 else { return }

        let padding: CGFloat = 10
        let plotRect = CGRect(
            x: padding, y: padding,
            width: size.width - padding * 2,
            height: size.height - padding * 2
        )

        let elevations = trackPoints.map(\.elevation)
        let minEle = elevations.min() ?? 0
        let maxEle = elevations.max() ?? 0
        let eleRange = max(maxEle - minEle, 1)
        let maxDist = trackPoints.last?.distance ?? 1

        let points = trackPoints.map { pt -> CGPoint in
            let x = plotRect.minX + CGFloat(pt.distance / maxDist) * plotRect.width
            let y = plotRect.maxY - CGFloat((pt.elevation - minEle) / eleRange) * plotRect.height
            return CGPoint(x: x, y: y)
        }

        let cursorX = plotRect.minX + progress * plotRect.width

        // Draw segments in accent color
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]

            guard p0.x <= cursorX else { break }

            let clippedEnd: CGPoint
            if p1.x <= cursorX {
                clippedEnd = p1
            } else {
                let t = (cursorX - p0.x) / (p1.x - p0.x)
                clippedEnd = CGPoint(x: cursorX, y: p0.y + t * (p1.y - p0.y))
            }

            // Fill under the segment
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: p0.x, y: plotRect.maxY))
            fillPath.addLine(to: p0)
            fillPath.addLine(to: clippedEnd)
            fillPath.addLine(to: CGPoint(x: clippedEnd.x, y: plotRect.maxY))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(TM.accent.opacity(0.1)))

            // Line
            var linePath = Path()
            linePath.move(to: p0)
            linePath.addLine(to: clippedEnd)

            context.stroke(
                linePath,
                with: .color(TM.accent),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }

        // Cursor glow (only while animating)
        if progress < 1.0 {
            let cursorY: CGFloat
            if let lastVisible = points.last(where: { $0.x <= cursorX }) {
                cursorY = lastVisible.y
            } else {
                cursorY = plotRect.midY
            }

            let glowRect = CGRect(x: cursorX - 10, y: cursorY - 10, width: 20, height: 20)
            context.fill(Path(ellipseIn: glowRect), with: .color(TM.accent.opacity(0.25)))

            let dotRect = CGRect(x: cursorX - 4, y: cursorY - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: dotRect), with: .color(TM.accent))
        }
    }
}
