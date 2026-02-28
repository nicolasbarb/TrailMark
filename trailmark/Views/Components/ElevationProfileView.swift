import SwiftUI
import UIKit

// MARK: - Horizontal Pan Gesture (UIKit)

/// Geste de pan horizontal avec support des taps
/// - Pan horizontal : capturé pour le curseur
/// - Pan vertical : passé à la sheet parente
/// - Tap : passé au callback onTap
struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    let onPan: (CGPoint, UIGestureRecognizer.State) -> Void
    let onTap: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIPanGestureRecognizer,
        context: Context
    ) {
        guard let view = recognizer.view else { return }
        let location = recognizer.location(in: view)
        let translation = recognizer.translation(in: view)

        // Détecter un tap : mouvement minimal à la fin du geste
        if recognizer.state == .ended || recognizer.state == .cancelled {
            let totalMovement = abs(translation.x) + abs(translation.y)
            if totalMovement < 10 {
                // C'est un tap, pas un drag
                onTap(location)
                return
            }
        }

        onPan(location, recognizer.state)
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Toujours commencer le geste pour pouvoir détecter les taps
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return true
            }

            let velocity = pan.velocity(in: pan.view)
            // Si le mouvement est vertical, laisser les autres gestes fonctionner
            if abs(velocity.y) > abs(velocity.x) * 1.5 {
                return true
            }
            return false
        }
    }
}

// MARK: - Elevation Profile View

struct ElevationProfileView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    @Binding var cursorPointIndex: Int?
    let onTap: (Int) -> Void

    @State private var dragLocation: CGPoint?
    @State private var tooltipData: TooltipData?
    @State private var lastHapticIndex: Int?


    struct TooltipData: Equatable {
        let x: CGFloat
        let altitude: Double
        let distance: Double
    }

    private let paddingTop: CGFloat = 14
    private let paddingBottom: CGFloat = 20
    private let paddingLeft: CGFloat = 38
    private let paddingRight: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Background
                TM.bgSecondary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Mini header
                    HStack {
                        Text("PROFIL")
                            .font(.system(.caption2, design: .monospaced, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(TM.textMuted)

                        Spacer()

                        Text("Tap = repère")
                            .font(.system(size: 9))
                            .foregroundStyle(TM.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)

                    // Canvas
                    GeometryReader { geometry in
                        ZStack {
                            Canvas { context, size in
                                drawProfile(context: context, size: size)
                            }
                            // Geste combiné: pan horizontal + tap
                            .gesture(
                                HorizontalPanGesture(
                                    onPan: { location, state in
                                        switch state {
                                        case .changed:
                                            handleDrag(location: location, size: geometry.size)
                                        case .ended, .cancelled:
                                            clearCursor()
                                        default:
                                            break
                                        }
                                    },
                                    onTap: { location in
                                        handleTap(location: location, size: geometry.size)
                                    }
                                )
                            )

                            // Tooltip overlay
                            if let tooltip = tooltipData {
                                tooltipView(data: tooltip, size: geometry.size)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Drawing

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

        // Draw grid
        drawGrid(context: context, plotRect: plotRect, minEle: minEle, maxEle: maxEle, maxDist: maxDist)

        // Draw fill
        drawFill(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange, maxDist: maxDist)

        // Draw elevation line
        drawElevationLine(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange, maxDist: maxDist)

        // Draw milestone markers
        drawMilestones(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange, maxDist: maxDist)

        // Draw cursor
        if let index = cursorPointIndex, let location = dragLocation {
            drawCursor(context: context, plotRect: plotRect, x: location.x, index: index, minEle: minEle, eleRange: eleRange, maxDist: maxDist)
        }
    }

    private func drawGrid(context: GraphicsContext, plotRect: CGRect, minEle: Double, maxEle: Double, maxDist: Double) {
        let eleRange = maxEle - minEle
        let eleStep = niceStep(eleRange, maxTicks: 4)
        let startEle = (floor(minEle / eleStep) * eleStep)

        // Horizontal grid lines and altitude labels
        var ele = startEle
        while ele <= maxEle + eleStep {
            let y = plotRect.maxY - CGFloat((ele - minEle) / eleRange) * plotRect.height

            if y >= plotRect.minY && y <= plotRect.maxY {
                // Grid line
                var linePath = Path()
                linePath.move(to: CGPoint(x: plotRect.minX, y: y))
                linePath.addLine(to: CGPoint(x: plotRect.maxX, y: y))
                context.stroke(linePath, with: .color(.white.opacity(0.06)), lineWidth: 0.5)

                // Label
                let text = Text("\(Int(ele))")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                context.draw(text, at: CGPoint(x: plotRect.minX - 4, y: y), anchor: .trailing)
            }

            ele += eleStep
        }

        // Distance labels
        let distStep = niceStep(maxDist / 1000, maxTicks: 5)
        var dist: Double = 0
        while dist <= maxDist / 1000 {
            let x = plotRect.minX + CGFloat(dist * 1000 / maxDist) * plotRect.width

            let text = Text("\(Int(dist))k")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
            context.draw(text, at: CGPoint(x: x, y: plotRect.maxY + 8), anchor: .top)

            dist += distStep
        }
    }

    private func drawFill(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double, maxDist: Double) {
        var fillPath = Path()

        for (index, point) in trackPoints.enumerated() {
            let x = plotRect.minX + CGFloat(point.distance / maxDist) * plotRect.width
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if index == 0 {
                fillPath.move(to: CGPoint(x: x, y: plotRect.maxY))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        if let last = trackPoints.last {
            let lastX = plotRect.minX + CGFloat(last.distance / maxDist) * plotRect.width
            fillPath.addLine(to: CGPoint(x: lastX, y: plotRect.maxY))
        }
        fillPath.closeSubpath()

        let gradient = Gradient(colors: [TM.trace.opacity(0.2), TM.trace.opacity(0.02)])
        context.fill(fillPath, with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: plotRect.minY), endPoint: CGPoint(x: 0, y: plotRect.maxY)))
    }

    private func drawElevationLine(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double, maxDist: Double) {
        var linePath = Path()

        for (index, point) in trackPoints.enumerated() {
            let x = plotRect.minX + CGFloat(point.distance / maxDist) * plotRect.width
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if index == 0 {
                linePath.move(to: CGPoint(x: x, y: y))
            } else {
                linePath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(linePath, with: .color(TM.trace), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
    }

    private func drawMilestones(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double, maxDist: Double) {
        for (index, milestone) in milestones.enumerated() {
            let x = plotRect.minX + CGFloat(milestone.distance / maxDist) * plotRect.width
            let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

            // Dashed line down
            var dashPath = Path()
            dashPath.move(to: CGPoint(x: x, y: y))
            dashPath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(dashPath, with: .color(TM.accent.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

            // Circle background
            let circleRect = CGRect(x: x - 6, y: y - 6, width: 12, height: 12)
            context.fill(Path(ellipseIn: circleRect), with: .color(milestone.milestoneType.color))

            // Circle border
            context.stroke(Path(ellipseIn: circleRect), with: .color(TM.bgPrimary), lineWidth: 2)

            // Number
            let text = Text("\(index + 1)")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            context.draw(text, at: CGPoint(x: x, y: y), anchor: .center)
        }
    }

    private func drawCursor(context: GraphicsContext, plotRect: CGRect, x: CGFloat, index: Int, minEle: Double, eleRange: Double, maxDist: Double) {
        guard index < trackPoints.count else { return }
        let point = trackPoints[index]
        let pointX = plotRect.minX + CGFloat(point.distance / maxDist) * plotRect.width
        let pointY = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

        // Dashed vertical line
        var dashPath = Path()
        dashPath.move(to: CGPoint(x: pointX, y: plotRect.minY))
        dashPath.addLine(to: CGPoint(x: pointX, y: plotRect.maxY))
        context.stroke(dashPath, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

        // Point
        let pointRect = CGRect(x: pointX - 4, y: pointY - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: pointRect), with: .color(.white))
        context.stroke(Path(ellipseIn: pointRect), with: .color(TM.trace), lineWidth: 1.5)
    }

    // MARK: - Tooltip

    private func tooltipView(data: TooltipData, size: CGSize) -> some View {
        let tooltipWidth: CGFloat = 70
        let clampedX = min(max(data.x, tooltipWidth / 2 + 8), size.width - tooltipWidth / 2 - 8)

        return VStack(spacing: 2) {
            Text("\(Int(data.altitude))m")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(TM.textPrimary)
            Text("km \(String(format: "%.1f", data.distance / 1000))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(TM.textMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(TM.bgPrimary.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(TM.border, lineWidth: 1)
        )
        .position(x: clampedX, y: paddingTop + 20)
    }

    // MARK: - Gesture Handling

    private func handleDrag(location: CGPoint, size: CGSize) {
        let plotRect = CGRect(
            x: paddingLeft,
            y: paddingTop,
            width: size.width - paddingLeft - paddingRight,
            height: size.height - paddingTop - paddingBottom
        )

        let clampedX = min(max(location.x, plotRect.minX), plotRect.maxX)
        let progress = (clampedX - plotRect.minX) / plotRect.width
        let maxDist = trackPoints.last?.distance ?? 1
        let targetDist = Double(progress) * maxDist

        // Binary search for closest point
        let index = findClosestPointIndex(distance: targetDist)

        dragLocation = CGPoint(x: clampedX, y: location.y)
        cursorPointIndex = index

        // Trigger haptic when cursor moves significantly (every ~20 points)
        let hapticThreshold = max(trackPoints.count / 50, 5)
        if let lastIndex = lastHapticIndex {
            if abs(index - lastIndex) >= hapticThreshold {
                Haptic.selection.trigger()
                lastHapticIndex = index
            }
        } else {
            lastHapticIndex = index
        }

        if index < trackPoints.count {
            let point = trackPoints[index]
            tooltipData = TooltipData(x: clampedX, altitude: point.elevation, distance: point.distance)
        }
    }

    private func handleTap(location: CGPoint, size: CGSize) {
        let plotRect = CGRect(
            x: paddingLeft,
            y: paddingTop,
            width: size.width - paddingLeft - paddingRight,
            height: size.height - paddingTop - paddingBottom
        )

        let clampedX = min(max(location.x, plotRect.minX), plotRect.maxX)
        let progress = (clampedX - plotRect.minX) / plotRect.width
        let maxDist = trackPoints.last?.distance ?? 1
        let targetDist = Double(progress) * maxDist

        let index = findClosestPointIndex(distance: targetDist)
        Haptic.medium.trigger()
        onTap(index)
    }

    private func clearCursor() {
        dragLocation = nil
        cursorPointIndex = nil
        tooltipData = nil
        lastHapticIndex = nil
    }

    private func findClosestPointIndex(distance: Double) -> Int {
        guard !trackPoints.isEmpty else { return 0 }

        var low = 0
        var high = trackPoints.count - 1

        while low < high {
            let mid = (low + high) / 2
            if trackPoints[mid].distance < distance {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Check which is closer: low or low-1
        if low > 0 {
            let distToLow = abs(trackPoints[low].distance - distance)
            let distToPrev = abs(trackPoints[low - 1].distance - distance)
            if distToPrev < distToLow {
                return low - 1
            }
        }

        return low
    }

    // MARK: - Helpers

    private func niceStep(_ range: Double, maxTicks: Int) -> Double {
        let roughStep = range / Double(maxTicks)
        let magnitude = pow(10, floor(log10(roughStep)))
        let residual = roughStep / magnitude

        let niceResidual: Double
        if residual <= 1.5 {
            niceResidual = 1
        } else if residual <= 3 {
            niceResidual = 2
        } else if residual <= 7 {
            niceResidual = 5
        } else {
            niceResidual = 10
        }

        return niceResidual * magnitude
    }
}

// Preview disabled due to Swift 6 type-check complexity
// #Preview {
//     ElevationProfileView(
//         trackPoints: [],
//         milestones: [],
//         cursorPointIndex: .constant(nil),
//         onTap: { _ in }
//     )
//     .frame(height: 170)
// }
