import SwiftUI
import UIKit

// MARK: - FPS Counter (DEBUG only)

#if DEBUG
import QuartzCore

@Observable
final class FPSCounter {
    private(set) var fps: Int = 0
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0

    init() {
        start()
    }

    func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp

        if elapsed >= 1.0 {
            fps = Int(Double(frameCount) / elapsed)
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }

    deinit {
        stop()
    }
}
#endif

// MARK: - Profile Image Renderer

private struct ProfileImageRenderer {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let pointSpacing: CGFloat
    let horizontalPadding: CGFloat
    let height: CGFloat
    let maxRenderPoints: Int

    private let paddingTop: CGFloat = 20
    private let paddingBottom: CGFloat = 30

    private var subsampleStep: Int {
        max(1, trackPoints.count / maxRenderPoints)
    }

    private var subsampledPoints: [(originalIndex: Int, point: TrackPoint)] {
        guard subsampleStep > 1 else {
            return trackPoints.enumerated().map { ($0.offset, $0.element) }
        }

        var result: [(Int, TrackPoint)] = []
        result.reserveCapacity(maxRenderPoints + 1)

        for i in stride(from: 0, to: trackPoints.count, by: subsampleStep) {
            result.append((i, trackPoints[i]))
        }

        if let last = trackPoints.last, result.last?.0 != trackPoints.count - 1 {
            result.append((trackPoints.count - 1, last))
        }

        return result
    }

    func render() -> UIImage? {
        guard trackPoints.count >= 2 else { return nil }

        let totalWidth = horizontalPadding * 2 + CGFloat(trackPoints.count) * pointSpacing
        let size = CGSize(width: totalWidth, height: height)

        let plotRect = CGRect(
            x: horizontalPadding,
            y: paddingTop,
            width: CGFloat(trackPoints.count) * pointSpacing,
            height: height - paddingTop - paddingBottom
        )

        var minEle = Double.infinity
        var maxEle = -Double.infinity
        for (_, point) in subsampledPoints {
            minEle = min(minEle, point.elevation)
            maxEle = max(maxEle, point.elevation)
        }
        let eleRange = max(maxEle - minEle, 1)

        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let context = ctx.cgContext
            drawProfile(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
            drawMilestones(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
        }
    }

    // Slope threshold for terrain classification (5%)
    private let slopeThreshold: Double = 0.05

    private enum TerrainType {
        case climbing, descending, flat

        var color: UIColor {
            switch self {
            case .climbing: return UIColor(MilestoneType.montee.color)
            case .descending: return UIColor(MilestoneType.descente.color)
            case .flat: return UIColor(MilestoneType.plat.color)
            }
        }
    }

    private func terrainType(from prevPoint: TrackPoint, to currPoint: TrackPoint) -> TerrainType {
        let distanceDelta = currPoint.distance - prevPoint.distance
        guard distanceDelta > 0 else { return .flat }

        let slope = (currPoint.elevation - prevPoint.elevation) / distanceDelta
        if slope > slopeThreshold {
            return .climbing
        } else if slope < -slopeThreshold {
            return .descending
        } else {
            return .flat
        }
    }

    private func drawProfile(context: CGContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        let points = subsampledPoints
        guard points.count >= 2 else { return }

        // Draw colored segments
        for i in 1..<points.count {
            let (prevIndex, prevPoint) = points[i - 1]
            let (currIndex, currPoint) = points[i]

            let terrain = terrainType(from: prevPoint, to: currPoint)
            let color = terrain.color

            let x1 = plotRect.minX + CGFloat(prevIndex) * pointSpacing
            let y1 = plotRect.maxY - CGFloat((prevPoint.elevation - minEle) / eleRange) * plotRect.height
            let x2 = plotRect.minX + CGFloat(currIndex) * pointSpacing
            let y2 = plotRect.maxY - CGFloat((currPoint.elevation - minEle) / eleRange) * plotRect.height

            // Draw fill for this segment
            let fillPath = CGMutablePath()
            fillPath.move(to: CGPoint(x: x1, y: plotRect.maxY))
            fillPath.addLine(to: CGPoint(x: x1, y: y1))
            fillPath.addLine(to: CGPoint(x: x2, y: y2))
            fillPath.addLine(to: CGPoint(x: x2, y: plotRect.maxY))
            fillPath.closeSubpath()

            context.addPath(fillPath)
            context.setFillColor(color.withAlphaComponent(0.15).cgColor)
            context.fillPath()

            // Draw line for this segment
            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: x1, y: y1))
            linePath.addLine(to: CGPoint(x: x2, y: y2))

            context.addPath(linePath)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
        }
    }

    private func drawMilestones(context: CGContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        for (index, milestone) in milestones.enumerated() {
            guard milestone.pointIndex < trackPoints.count else { continue }

            let x = plotRect.minX + CGFloat(milestone.pointIndex) * pointSpacing
            let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

            context.setStrokeColor(UIColor(TM.accent).withAlphaComponent(0.35).cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [3, 2])
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])

            let circleRect = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
            context.setFillColor(UIColor(milestone.milestoneType.color).cgColor)
            context.fillEllipse(in: circleRect)

            context.setStrokeColor(UIColor(TM.bgPrimary).cgColor)
            context.setLineWidth(2)
            context.strokeEllipse(in: circleRect)

            let text = "\(index + 1)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: x - textSize.width / 2,
                y: y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - Scrollable Elevation Profile View (120 FPS optimized)

struct ScrollableElevationProfileView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    @Binding var scrolledPointIndex: Int
    @Binding var scrollToIndex: Int?

    private let pointSpacing: CGFloat = 0.5
    private let maxRenderPoints: Int = 2000
    private let paddingTop: CGFloat = 20
    private let paddingBottom: CGFloat = 30

    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var profileImage: UIImage?
    @State private var isScrolling = false

    // Non-state tracking (doesn't trigger SwiftUI updates)
    private static var _currentOffset: CGFloat = 0
    private static var _pendingIndex: Int = 0
    private static var _lastHapticIndex: Int = 0
    private static var _lastHapticMilestoneId: Int64? = nil
    private static var _lastSyncedIndex: Int = 0

    #if DEBUG
    @State private var fpsCounter = FPSCounter()
    #endif

    private var milestoneIndices: Set<Int> {
        Set(milestones.map(\.pointIndex))
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = geometry.size.width / 2

            ZStack {
                TM.bgSecondary

                // Pure scroll - NO state updates during scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .interpolation(.none)
                    }
                }
                .scrollPosition($scrollPosition)
                // Track scroll offset (no SwiftUI state updates during scroll)
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.x
                } action: { _, newOffset in
                    // Store in static vars (no SwiftUI rebuild)
                    Self._currentOffset = newOffset

                    let index = Int(newOffset / pointSpacing)
                    let clampedIndex = max(0, min(index, trackPoints.count - 1))
                    Self._pendingIndex = clampedIndex

                    // Haptic feedback
                    triggerHapticIfNeeded(newIndex: clampedIndex)

                    // Sync to mini profile every 50 points (throttled for performance)
                    if abs(clampedIndex - Self._lastSyncedIndex) >= 50 {
                        scrolledPointIndex = clampedIndex
                        Self._lastSyncedIndex = clampedIndex
                    }
                }
                // Detect scroll phase to know when scrolling stops
                .onScrollPhaseChange { oldPhase, newPhase in
                    let wasScrolling = oldPhase != .idle
                    let nowIdle = newPhase == .idle

                    isScrolling = !nowIdle

                    // Commit position only when scroll stops
                    if wasScrolling && nowIdle {
                        commitScrollPosition()
                    }
                }
                .onChange(of: scrollToIndex) { _, newIndex in
                    handleProgrammaticScroll(targetIndex: newIndex)
                }

                // Active milestone highlight (only when NOT scrolling)
                if !isScrolling, let active = currentMilestoneUnderCursor {
                    ActiveMilestoneHighlight(
                        milestone: active.milestone,
                        index: active.index,
                        scrollOffset: CGFloat(scrolledPointIndex) * pointSpacing,
                        pointSpacing: pointSpacing,
                        height: geometry.size.height,
                        paddingTop: paddingTop,
                        paddingBottom: paddingBottom,
                        trackPoints: trackPoints
                    )
                }

                // Cursor overlay (static, always visible)
                cursorOverlay(height: geometry.size.height)

                // Triangle indicator
                VStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TM.accent)
                    Spacer()
                }
                .allowsHitTesting(false)

                #if DEBUG
                VStack {
                    Spacer()
                    HStack {
                        Text("\(fpsCounter.fps) FPS")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(fpsCounter.fps >= 100 ? .green : fpsCounter.fps >= 55 ? .yellow : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                        Spacer()
                    }
                    .padding(8)
                }
                .allowsHitTesting(false)
                #endif
            }
            .onAppear {
                renderProfileImage(horizontalPadding: horizontalPadding, height: geometry.size.height)
            }
            .onChange(of: trackPoints.count) { _, _ in
                renderProfileImage(horizontalPadding: horizontalPadding, height: geometry.size.height)
            }
            .onChange(of: milestones.count) { _, _ in
                renderProfileImage(horizontalPadding: horizontalPadding, height: geometry.size.height)
            }
        }
    }

    // MARK: - Commit scroll position (only when scroll stops)

    private func commitScrollPosition() {
        if Self._pendingIndex != scrolledPointIndex {
            scrolledPointIndex = Self._pendingIndex
        }
    }

    // MARK: - Milestone under cursor

    private var currentMilestoneUnderCursor: (index: Int, milestone: Milestone)? {
        for (index, milestone) in milestones.enumerated() {
            if abs(milestone.pointIndex - scrolledPointIndex) <= 3 {
                return (index, milestone)
            }
        }
        return nil
    }

    // MARK: - Haptic feedback (no SwiftUI state update)

    private func triggerHapticIfNeeded(newIndex: Int) {
        // Light haptic every 20 points
        if abs(newIndex - Self._lastHapticIndex) >= 20 {
            Haptic.light.trigger()
            Self._lastHapticIndex = newIndex
        }

        // Medium haptic on milestone crossing
        for milestone in milestones {
            let distance = abs(milestone.pointIndex - newIndex)
            if distance <= 1 && milestone.id != Self._lastHapticMilestoneId {
                Haptic.medium.trigger()
                Self._lastHapticMilestoneId = milestone.id
                Self._lastHapticIndex = newIndex
                return
            }
        }
    }

    // MARK: - Profile Image Rendering

    private func renderProfileImage(horizontalPadding: CGFloat, height: CGFloat) {
        let renderer = ProfileImageRenderer(
            trackPoints: trackPoints,
            milestones: milestones,
            pointSpacing: pointSpacing,
            horizontalPadding: horizontalPadding,
            height: height,
            maxRenderPoints: maxRenderPoints
        )
        profileImage = renderer.render()
    }

    // MARK: - Cursor Overlay

    private func cursorOverlay(height: CGFloat) -> some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2

            Path { path in
                path.move(to: CGPoint(x: centerX, y: paddingTop - 10))
                path.addLine(to: CGPoint(x: centerX, y: height - paddingBottom))
            }
            .stroke(TM.accent.opacity(0.8), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Programmatic Scroll

    private func handleProgrammaticScroll(targetIndex: Int?) {
        guard let targetIndex else { return }

        // Update position immediately for mini profile feedback
        scrolledPointIndex = targetIndex
        Self._pendingIndex = targetIndex
        Self._currentOffset = CGFloat(targetIndex) * pointSpacing

        let targetOffset = CGFloat(targetIndex) * pointSpacing

        withAnimation(.easeOut(duration: 0.25)) {
            scrollPosition.scrollTo(x: targetOffset)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            scrollToIndex = nil
        }
    }
}

// MARK: - Active Milestone Highlight

private struct ActiveMilestoneHighlight: View {
    let milestone: Milestone
    let index: Int
    let scrollOffset: CGFloat
    let pointSpacing: CGFloat
    let height: CGFloat
    let paddingTop: CGFloat
    let paddingBottom: CGFloat
    let trackPoints: [TrackPoint]

    private var yPosition: CGFloat {
        let plotHeight = height - paddingTop - paddingBottom

        var minEle = Double.infinity
        var maxEle = -Double.infinity
        for point in trackPoints {
            minEle = min(minEle, point.elevation)
            maxEle = max(maxEle, point.elevation)
        }
        let eleRange = max(maxEle - minEle, 1)

        return paddingTop + plotHeight - CGFloat((milestone.elevation - minEle) / eleRange) * plotHeight
    }

    private var xOffsetFromCenter: CGFloat {
        let milestoneX = CGFloat(milestone.pointIndex) * pointSpacing
        return milestoneX - scrollOffset
    }

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2

            ZStack {
                Circle()
                    .fill(milestone.milestoneType.color.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .blur(radius: 6)

                Circle()
                    .fill(milestone.milestoneType.color)
                    .frame(width: 26, height: 26)

                Circle()
                    .stroke(TM.bgPrimary, lineWidth: 3)
                    .frame(width: 26, height: 26)

                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .position(x: centerX + xOffsetFromCenter, y: yPosition)
        }
        .allowsHitTesting(false)
    }
}
