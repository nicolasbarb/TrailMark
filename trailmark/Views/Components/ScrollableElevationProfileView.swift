import SwiftUI

struct ScrollableElevationProfileView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    @Binding var scrolledPointIndex: Int

    private let pointSpacing: CGFloat = 4
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = geometry.size.width / 2
            let totalWidth = horizontalPadding * 2 + CGFloat(trackPoints.count) * pointSpacing

            ZStack {
                TM.bgSecondary

                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .leading) {
                        // Main Canvas
                        Canvas { context, size in
                            drawProfile(
                                context: context,
                                size: size,
                                horizontalPadding: horizontalPadding,
                                cursorX: scrollOffset + horizontalPadding
                            )
                        }
                        .frame(width: totalWidth, height: geometry.size.height)

                        // Scroll position tracker
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: -scrollGeometry.frame(in: .named("scroll")).origin.x
                                )
                        }
                        .frame(width: totalWidth, height: 1)
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    // Update scroll offset for cursor drawing
                    scrollOffset = offset

                    // Update point index
                    let index = Int(offset / pointSpacing)
                    let clampedIndex = max(0, min(index, trackPoints.count - 1))
                    if clampedIndex != scrolledPointIndex {
                        scrolledPointIndex = clampedIndex
                        Haptic.selection.trigger()
                    }
                }

                // Triangle indicator only (line is in Canvas)
                VStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TM.accent)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Drawing

    private func drawProfile(context: GraphicsContext, size: CGSize, horizontalPadding: CGFloat, cursorX: CGFloat) {
        guard trackPoints.count >= 2 else { return }

        let paddingTop: CGFloat = 20
        let paddingBottom: CGFloat = 30

        let plotRect = CGRect(
            x: horizontalPadding,
            y: paddingTop,
            width: CGFloat(trackPoints.count) * pointSpacing,
            height: size.height - paddingTop - paddingBottom
        )

        let elevations = trackPoints.map(\.elevation)
        let minEle = elevations.min() ?? 0
        let maxEle = elevations.max() ?? 0
        let eleRange = max(maxEle - minEle, 1)

        // 1. Draw fill
        drawFill(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

        // 2. Draw elevation line
        drawElevationLine(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

        // 3. Draw cursor (behind milestones)
        drawCursor(context: context, plotRect: plotRect, cursorX: cursorX)

        // 4. Draw milestones (on top)
        drawMilestones(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
    }

    private func drawFill(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        var fillPath = Path()

        for (index, point) in trackPoints.enumerated() {
            let x = plotRect.minX + CGFloat(index) * pointSpacing
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if index == 0 {
                fillPath.move(to: CGPoint(x: x, y: plotRect.maxY))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        let lastX = plotRect.minX + CGFloat(trackPoints.count - 1) * pointSpacing
        fillPath.addLine(to: CGPoint(x: lastX, y: plotRect.maxY))
        fillPath.closeSubpath()

        let gradient = Gradient(colors: [TM.trace.opacity(0.2), TM.trace.opacity(0.02)])
        context.fill(fillPath, with: .linearGradient(
            gradient,
            startPoint: CGPoint(x: 0, y: plotRect.minY),
            endPoint: CGPoint(x: 0, y: plotRect.maxY)
        ))
    }

    private func drawElevationLine(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        var linePath = Path()

        for (index, point) in trackPoints.enumerated() {
            let x = plotRect.minX + CGFloat(index) * pointSpacing
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if index == 0 {
                linePath.move(to: CGPoint(x: x, y: y))
            } else {
                linePath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(linePath, with: .color(TM.trace), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
    }

    private func drawCursor(context: GraphicsContext, plotRect: CGRect, cursorX: CGFloat) {
        var linePath = Path()
        linePath.move(to: CGPoint(x: cursorX, y: plotRect.minY - 10))
        linePath.addLine(to: CGPoint(x: cursorX, y: plotRect.maxY))
        context.stroke(linePath, with: .color(TM.accent.opacity(0.8)), style: StrokeStyle(lineWidth: 2))
    }

    private func drawMilestones(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        for (index, milestone) in milestones.enumerated() {
            guard milestone.pointIndex < trackPoints.count else { continue }

            let x = plotRect.minX + CGFloat(milestone.pointIndex) * pointSpacing
            let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

            // Dashed line down
            var dashPath = Path()
            dashPath.move(to: CGPoint(x: x, y: y))
            dashPath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(dashPath, with: .color(TM.accent.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

            // Circle background
            let circleRect = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
            context.fill(Path(ellipseIn: circleRect), with: .color(milestone.milestoneType.color))

            // Circle border
            context.stroke(Path(ellipseIn: circleRect), with: .color(TM.bgPrimary), lineWidth: 2)

            // Number
            let text = Text("\(index + 1)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            context.draw(text, at: CGPoint(x: x, y: y), anchor: .center)
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
