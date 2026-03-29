import SwiftUI

// MARK: - Elevation Profile Preview

struct ElevationProfilePreview: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    var showMilestones: Bool = true

    private let paddingTop: CGFloat = 10
    private let paddingBottom: CGFloat = 10
    private let paddingLeft: CGFloat = 10
    private let paddingRight: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            drawProfile(context: context, size: size)
        }
        .background(TM.bgSecondary)
    }

    private func drawProfile(context: GraphicsContext, size: CGSize) {
        guard trackPoints.count >= 2 else { return }

        let plotRect = CGRect(
            x: paddingLeft,
            y: paddingTop,
            width: size.width - paddingLeft - paddingRight,
            height: size.height - paddingTop - paddingBottom
        )

        let elevations = trackPoints.map(\.elevation)
        let minEle = elevations.min() ?? 0
        let maxEle = elevations.max() ?? 0
        let eleRange = max(maxEle - minEle, 1)
        let maxDist = trackPoints.last?.distance ?? 1

        // Classify on full data, then downsample for drawing performance
        let terrainTypes = ElevationProfileAnalyzer.classify(trackPoints: trackPoints)

        let step = max(1, trackPoints.count / 300)
        let sampledIndices = Array(stride(from: 0, to: trackPoints.count, by: step))
        let sampledPoints = sampledIndices.map { trackPoints[$0] }
        let sampledTerrains = sampledIndices.map { terrainTypes[$0] }

        drawColoredSegments(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange, maxDist: maxDist, points: sampledPoints, terrainTypes: sampledTerrains)

        if showMilestones {
            drawMilestones(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange, maxDist: maxDist)
        }
    }

    private func drawColoredSegments(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double, maxDist: Double, points: [TrackPoint], terrainTypes: [TerrainType]) {
        guard points.count >= 2 else { return }

        for i in 1..<points.count {
            let prevPoint = points[i - 1]
            let currPoint = points[i]
            let terrain = terrainTypes[i]

            let x1 = plotRect.minX + CGFloat(prevPoint.distance / maxDist) * plotRect.width
            let y1 = plotRect.maxY - CGFloat((prevPoint.elevation - minEle) / eleRange) * plotRect.height
            let x2 = plotRect.minX + CGFloat(currPoint.distance / maxDist) * plotRect.width
            let y2 = plotRect.maxY - CGFloat((currPoint.elevation - minEle) / eleRange) * plotRect.height

            var fillPath = Path()
            fillPath.move(to: CGPoint(x: x1, y: plotRect.maxY))
            fillPath.addLine(to: CGPoint(x: x1, y: y1))
            fillPath.addLine(to: CGPoint(x: x2, y: y2))
            fillPath.addLine(to: CGPoint(x: x2, y: plotRect.maxY))
            fillPath.closeSubpath()

            context.fill(fillPath, with: .color(terrain.color.opacity(0.2)))

            var linePath = Path()
            linePath.move(to: CGPoint(x: x1, y: y1))
            linePath.addLine(to: CGPoint(x: x2, y: y2))

            context.stroke(linePath, with: .color(terrain.color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawMilestones(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double, maxDist: Double) {
        for (index, milestone) in milestones.enumerated() {
            let x = plotRect.minX + CGFloat(milestone.distance / maxDist) * plotRect.width
            let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

            var dashPath = Path()
            dashPath.move(to: CGPoint(x: x, y: y))
            dashPath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(dashPath, with: .color(TM.accent.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

            let circleRect = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: circleRect), with: .color(milestone.milestoneType.color))
            context.stroke(Path(ellipseIn: circleRect), with: .color(TM.bgPrimary), lineWidth: 1.5)

            let text = Text("\(index + 1)")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            context.draw(text, at: CGPoint(x: x, y: y), anchor: .center)
        }
    }
}

// MARK: - Milestone Markers Overlay (SwiftUI views for animated appearance)

struct MilestoneMarkersOverlay: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let visibleCount: Int

    private let padding: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let plotRect = CGRect(
                x: padding, y: padding,
                width: geo.size.width - padding * 2,
                height: geo.size.height - padding * 2
            )
            let elevations = trackPoints.map(\.elevation)
            let minEle = elevations.min() ?? 0
            let maxEle = elevations.max() ?? 0
            let eleRange = max(maxEle - minEle, 1)
            let maxDist = trackPoints.last?.distance ?? 1

            ForEach(Array(milestones.prefix(visibleCount).enumerated()), id: \.offset) { index, milestone in
                let x = plotRect.minX + CGFloat(milestone.distance / maxDist) * plotRect.width
                let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

                MilestoneMarkerView(
                    color: milestone.milestoneType.color,
                    index: index + 1
                )
                .position(x: x, y: y)
            }
        }
    }
}

struct MilestoneMarkerView: View {
    let color: Color
    let index: Int

    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Circle()
                .strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: 12, height: 12)

            Text("\(index)")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .scaleEffect(appeared ? 1 : 0)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.4)) {
                appeared = true
            }
        }
    }
}
