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

    private let paddingTop: CGFloat = 16
    private let paddingBottom: CGFloat = 16

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

    private var imageSize: CGSize {
        let totalWidth = horizontalPadding * 2 + CGFloat(trackPoints.count) * pointSpacing
        return CGSize(width: totalWidth, height: height)
    }

    private var plotRect: CGRect {
        CGRect(
            x: horizontalPadding,
            y: paddingTop,
            width: CGFloat(trackPoints.count) * pointSpacing,
            height: height - paddingTop - paddingBottom
        )
    }

    private var elevationBounds: (min: Double, range: Double) {
        var minEle = Double.infinity
        var maxEle = -Double.infinity
        for point in trackPoints {
            minEle = min(minEle, point.elevation)
            maxEle = max(maxEle, point.elevation)
        }
        return (minEle, max(maxEle - minEle, 1))
    }

    func renderProfile() -> UIImage? {
        guard trackPoints.count >= 2 else { return nil }
        let (minEle, eleRange) = elevationBounds
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { ctx in
            drawProfile(context: ctx.cgContext, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
        }
    }

    func renderMilestones() -> UIImage? {
        guard trackPoints.count >= 2, !milestones.isEmpty else { return nil }
        let (minEle, eleRange) = elevationBounds
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { ctx in
            drawMilestones(context: ctx.cgContext, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
        }
    }

    private func drawProfile(context: CGContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        let points = subsampledPoints
        guard points.count >= 2 else { return }

        // Use shared ElevationProfileAnalyzer
        let terrainTypes = ElevationProfileAnalyzer.classify(trackPoints: trackPoints)

        // Draw colored segments
        for i in 1..<points.count {
            let (prevIndex, prevPoint) = points[i - 1]
            let (currIndex, currPoint) = points[i]

            // Use terrain type of current point (already smoothed)
            let terrain = terrainTypes[currIndex]
            let color = terrain.uiColor

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

// MARK: - Scroll Cursor Line (inside scroll content, tracks viewport center)

private struct ScrollCursorLine: View {
    let paddingTop: CGFloat
    let paddingBottom: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .scrollView)
            let viewportWidth = proxy.bounds(of: .scrollView)?.width ?? 0
            let cursorX = -frame.minX + viewportWidth / 2

            Path { path in
                path.move(to: CGPoint(x: cursorX, y: paddingTop - 10))
                path.addLine(to: CGPoint(x: cursorX, y: height - paddingBottom))
            }
            .stroke(Color.secondary, lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Scroll Sync State (instance-level, avoids static var issues)

private final class ScrollSyncState {
    var currentOffset: CGFloat = 0
    var pendingIndex: Int = 0
    var lastSyncedIndex: Int = 0
}

// MARK: - Scroll Target

struct ScrollTarget: Equatable {
    let index: Int
    let animated: Bool
}

// MARK: - Scrollable Elevation Profile View (120 FPS optimized)

struct ScrollableElevationProfileView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let editingMilestoneId: Int64?
    @Binding var scrollTarget: ScrollTarget?
    var onScrollIndexChanged: ((Int) -> Void)?
    var onMilestoneTapped: ((Milestone) -> Void)?

    private let pointSpacing: CGFloat = 0.5
    private let maxRenderPoints: Int = 2000
    private let paddingTop: CGFloat = 16
    private let paddingBottom: CGFloat = 16

    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var profileImage: UIImage?
    @State private var milestonesImage: UIImage?
    @State private var isScrolling = false
    @State private var localScrollIndex: Int = 0

    // Instance-level tracking (avoids static variable sharing issues)
    @State private var syncState = ScrollSyncState()

    #if DEBUG
    @State private var fpsCounter = FPSCounter()
    #endif

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = geometry.size.width / 2

            ZStack {
                TM.bgSecondary

                // Pure scroll - NO state updates during scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    // Profile image as base, with cursor + milestones layered via overlay
                    profileImageContent(height: geometry.size.height)
                }
                .scrollPosition($scrollPosition)
                // Track scroll offset - NO @State updates during scroll
                .onScrollGeometryChange(for: Int.self) { geo in
                    let index = Int(geo.contentOffset.x / 0.5)
                    return max(0, index)
                } action: { oldIndex, newIndex in
                    syncState.currentOffset = CGFloat(newIndex) * 0.5
                    syncState.pendingIndex = newIndex

                    // Update data and haptic every 2 points
                    if newIndex / 2 != oldIndex / 2 {
                        onScrollIndexChanged?(newIndex)
                        Haptic.selection.trigger()
                    }

                }
                // Detect scroll phase
                .onScrollPhaseChange { oldPhase, newPhase in
                    isScrolling = newPhase != .idle
                    // Pre-warm Taptic Engine when scroll begins
                    if oldPhase == .idle && newPhase != .idle {
                        Haptic.selection.prepare()
                    }
                    // Commit position when scroll stops (for milestone tap overlay)
                    if oldPhase != .idle && newPhase == .idle {
                        localScrollIndex = syncState.pendingIndex
                    }
                }
                .onChange(of: scrollTarget) { _, newTarget in
                    handleProgrammaticScroll(target: newTarget)
                }

                // Triangle indicator
                VStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }
                .allowsHitTesting(false)

                // Tappable milestone zones
                MilestoneTapOverlay(
                    milestones: milestones,
                    trackPoints: trackPoints,
                    scrollOffset: CGFloat(localScrollIndex) * pointSpacing,
                    pointSpacing: pointSpacing,
                    viewWidth: geometry.size.width,
                    height: geometry.size.height,
                    paddingTop: paddingTop,
                    paddingBottom: paddingBottom,
                    onTap: { milestone in
                        Haptic.medium.trigger()
                        onMilestoneTapped?(milestone)
                    }
                )

                // Editing milestone highlight (scaled up)
                if let editingId = editingMilestoneId,
                   let editingMilestone = milestones.first(where: { $0.id == editingId }),
                   let index = milestones.firstIndex(where: { $0.id == editingId }) {
                    EditingMilestoneHighlight(
                        milestone: editingMilestone,
                        index: index,
                        scrollOffset: CGFloat(localScrollIndex) * pointSpacing,
                        pointSpacing: pointSpacing,
                        height: geometry.size.height,
                        paddingTop: paddingTop,
                        paddingBottom: paddingBottom,
                        trackPoints: trackPoints
                    )
                }

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
                if geometry.size.height > 0 {
                    renderProfileImage(horizontalPadding: horizontalPadding, height: geometry.size.height)
                }
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                if newHeight > 0 {
                    renderProfileImage(horizontalPadding: horizontalPadding, height: newHeight)
                }
            }
            .onChange(of: trackPoints.count) { _, _ in
                if geometry.size.height > 0 {
                    renderProfileImage(horizontalPadding: horizontalPadding, height: geometry.size.height)
                }
            }
            .onChange(of: milestones.count) { _, _ in
                if geometry.size.height > 0 {
                    renderProfileImage(horizontalPadding: horizontalPadding, height: geometry.size.height)
                }
            }
        }
    }

    // MARK: - Scroll Content (profile → cursor → milestones)

    private func profileImageContent(height: CGFloat) -> some View {
        Group {
            if let image = profileImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(height: height)
                    .overlay {
                        // Layer 2: Cursor line (tracks viewport center)
                        ScrollCursorLine(paddingTop: paddingTop, paddingBottom: paddingBottom, height: height)
                    }
                    .overlay {
                        // Layer 3: Milestones on top of cursor
                        if let msImage = milestonesImage {
                            Image(uiImage: msImage)
                                .interpolation(.none)
                                .resizable()
                                .frame(height: height)
                                .allowsHitTesting(false)
                        }
                    }
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
        profileImage = renderer.renderProfile()
        milestonesImage = renderer.renderMilestones()
    }

    // MARK: - Programmatic Scroll

    private func handleProgrammaticScroll(target: ScrollTarget?) {
        guard let target else { return }

        let targetIndex = target.index

        // Update position immediately
        localScrollIndex = targetIndex
        onScrollIndexChanged?(targetIndex)
        syncState.pendingIndex = targetIndex
        syncState.lastSyncedIndex = targetIndex
        syncState.currentOffset = CGFloat(targetIndex) * pointSpacing

        let targetOffset = CGFloat(targetIndex) * pointSpacing

        if target.animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                scrollPosition.scrollTo(x: targetOffset)
            }
        } else {
            scrollPosition.scrollTo(x: targetOffset)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            scrollTarget = nil
        }
    }
}

// MARK: - Editing Milestone Highlight (Scaled up)

private struct EditingMilestoneHighlight: View {
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

            HighlightBubble(milestone: milestone, index: index)
                .position(x: centerX + xOffsetFromCenter, y: yPosition)
        }
        .allowsHitTesting(false)
    }
}

private struct HighlightBubble: View {
    let milestone: Milestone
    let index: Int
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(milestone.milestoneType.color.opacity(0.3))
                .frame(width: 50, height: 50)
                .blur(radius: 10)

            // Inner glow
            Circle()
                .fill(milestone.milestoneType.color.opacity(0.5))
                .frame(width: 40, height: 40)
                .blur(radius: 6)

            // Main circle
            Circle()
                .fill(milestone.milestoneType.color)
                .frame(width: 32, height: 32)

            // Border
            Circle()
                .stroke(TM.bgPrimary, lineWidth: 3)
                .frame(width: 32, height: 32)

            // Number
            Text("\(index + 1)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .scaleEffect(appeared ? 1 : 0.01)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                appeared = true
            }
        }
    }
}

// MARK: - Milestone Tap Overlay

private struct MilestoneTapOverlay: View {
    let milestones: [Milestone]
    let trackPoints: [TrackPoint]
    let scrollOffset: CGFloat
    let pointSpacing: CGFloat
    let viewWidth: CGFloat
    let height: CGFloat
    let paddingTop: CGFloat
    let paddingBottom: CGFloat
    let onTap: (Milestone) -> Void

    private var elevationRange: (min: Double, max: Double) {
        var minEle = Double.infinity
        var maxEle = -Double.infinity
        for point in trackPoints {
            minEle = min(minEle, point.elevation)
            maxEle = max(maxEle, point.elevation)
        }
        return (minEle, max(maxEle - minEle, 1))
    }

    var body: some View {
        let centerX = viewWidth / 2
        let plotHeight = height - paddingTop - paddingBottom
        let (minEle, eleRange) = elevationRange

        ZStack {
            ForEach(milestones) { milestone in
                let milestoneX = CGFloat(milestone.pointIndex) * pointSpacing
                let xPosition = centerX + (milestoneX - scrollOffset)

                if xPosition > -30 && xPosition < viewWidth + 30 {
                    let yPosition = paddingTop + plotHeight - CGFloat((milestone.elevation - minEle) / eleRange) * plotHeight

                    Button {
                        onTap(milestone)
                    } label: {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                    }
                    .position(x: xPosition, y: yPosition)
                }
            }
        }
    }
}

// MARK: - Elevation Stats Overlay (Glassmorphic)

struct ElevationStatsOverlay: View {
    let altitude: Int
    let dPlus: Int
    let dMinus: Int

    var body: some View {
        HStack(spacing: 8) {
            // Altitude
            statItem(value: "\(altitude)", unit: "m", isPrimary: true)

            divider

            // D+
            statItem(value: "+\(dPlus)", unit: "m", color: MilestoneType.montee.color)

            divider

            // D-
            statItem(value: "-\(dMinus)", unit: "m", color: MilestoneType.descente.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func statItem(value: String, unit: String, isPrimary: Bool = false, color: Color? = nil) -> some View {
        HStack(spacing: 1) {
            Text(value)
                .font(.system(size: isPrimary ? 12 : 11, weight: isPrimary ? .semibold : .medium, design: .monospaced))
                .foregroundStyle(color ?? TM.textPrimary)

            Text(unit)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(TM.textTertiary)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 16)
    }
}
