import SwiftUI

struct MiniProfileView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let currentIndex: Int
    let onIndexSelected: (Int) -> Void

    private let height: CGFloat = 50
    private let paddingH: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard trackPoints.count >= 2 else { return }

                let paddingV: CGFloat = 8

                let plotRect = CGRect(
                    x: paddingH,
                    y: paddingV,
                    width: size.width - paddingH * 2,
                    height: size.height - paddingV * 2
                )

                let elevations = trackPoints.map(\.elevation)
                let minEle = elevations.min() ?? 0
                let maxEle = elevations.max() ?? 0
                let eleRange = max(maxEle - minEle, 1)

                // Draw fill
                drawFill(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

                // Draw line
                drawLine(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

                // Draw cursor (behind milestones)
                drawCursor(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

                // Draw milestones (small dots, on top)
                drawMilestones(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = indexFromLocation(value.location.x, width: geometry.size.width)
                        onIndexSelected(index)
                    }
            )
        }
        .frame(height: height)
        .background(TM.bgSecondary)
    }

    // MARK: - Touch to Index

    private func indexFromLocation(_ x: CGFloat, width: CGFloat) -> Int {
        let plotWidth = width - paddingH * 2
        let clampedX = max(paddingH, min(x, width - paddingH))
        let progress = (clampedX - paddingH) / plotWidth
        let index = Int(progress * CGFloat(trackPoints.count - 1))
        return max(0, min(index, trackPoints.count - 1))
    }

    // MARK: - Drawing

    private func drawFill(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        var fillPath = Path()
        let pointCount = trackPoints.count

        for (index, point) in trackPoints.enumerated() {
            let progress = CGFloat(index) / CGFloat(pointCount - 1)
            let x = plotRect.minX + progress * plotRect.width
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if index == 0 {
                fillPath.move(to: CGPoint(x: x, y: plotRect.maxY))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        fillPath.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.maxY))
        fillPath.closeSubpath()

        let gradient = Gradient(colors: [TM.trace.opacity(0.15), TM.trace.opacity(0.02)])
        context.fill(fillPath, with: .linearGradient(
            gradient,
            startPoint: CGPoint(x: 0, y: plotRect.minY),
            endPoint: CGPoint(x: 0, y: plotRect.maxY)
        ))
    }

    private func drawLine(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        var linePath = Path()
        let pointCount = trackPoints.count

        for (index, point) in trackPoints.enumerated() {
            let progress = CGFloat(index) / CGFloat(pointCount - 1)
            let x = plotRect.minX + progress * plotRect.width
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if index == 0 {
                linePath.move(to: CGPoint(x: x, y: y))
            } else {
                linePath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(linePath, with: .color(TM.trace.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
    }

    private func drawMilestones(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        let pointCount = trackPoints.count

        for milestone in milestones {
            guard milestone.pointIndex < pointCount else { continue }

            let progress = CGFloat(milestone.pointIndex) / CGFloat(pointCount - 1)
            let x = plotRect.minX + progress * plotRect.width
            let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

            // Small dot
            let dotRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dotRect), with: .color(milestone.milestoneType.color))
        }
    }

    private func drawCursor(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        guard currentIndex >= 0, currentIndex < trackPoints.count else { return }

        let pointCount = trackPoints.count
        let point = trackPoints[currentIndex]

        let progress = CGFloat(currentIndex) / CGFloat(pointCount - 1)
        let x = plotRect.minX + progress * plotRect.width
        let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

        // Vertical line
        var linePath = Path()
        linePath.move(to: CGPoint(x: x, y: plotRect.minY))
        linePath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
        context.stroke(linePath, with: .color(TM.accent), style: StrokeStyle(lineWidth: 1.5))

        // Cursor dot
        let dotRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: dotRect), with: .color(TM.accent))
        context.stroke(Path(ellipseIn: dotRect), with: .color(.white), lineWidth: 1.5)
    }
}
