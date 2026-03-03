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

// MARK: - Profile Image Renderer (with milestones)

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

        // Compute elevation range
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

            // Draw profile (fill + line)
            drawProfile(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

            // Draw milestones (static, in image)
            drawMilestones(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
        }
    }

    private func drawProfile(context: CGContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        let fillPath = CGMutablePath()
        let linePath = CGMutablePath()

        var isFirst = true
        var lastX: CGFloat = plotRect.minX

        for (originalIndex, point) in subsampledPoints {
            let x = plotRect.minX + CGFloat(originalIndex) * pointSpacing
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if isFirst {
                fillPath.move(to: CGPoint(x: x, y: plotRect.maxY))
                fillPath.addLine(to: CGPoint(x: x, y: y))
                linePath.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                fillPath.addLine(to: CGPoint(x: x, y: y))
                linePath.addLine(to: CGPoint(x: x, y: y))
            }
            lastX = x
        }

        fillPath.addLine(to: CGPoint(x: lastX, y: plotRect.maxY))
        fillPath.closeSubpath()

        // Draw fill
        context.addPath(fillPath)
        context.setFillColor(UIColor(TM.trace).withAlphaComponent(0.12).cgColor)
        context.fillPath()

        // Draw line
        context.addPath(linePath)
        context.setStrokeColor(UIColor(TM.trace).cgColor)
        context.setLineWidth(2)
        context.setLineJoin(.round)
        context.strokePath()
    }

    private func drawMilestones(context: CGContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        for (index, milestone) in milestones.enumerated() {
            guard milestone.pointIndex < trackPoints.count else { continue }

            let x = plotRect.minX + CGFloat(milestone.pointIndex) * pointSpacing
            let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

            // Dashed vertical line
            context.setStrokeColor(UIColor(TM.accent).withAlphaComponent(0.35).cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [3, 2])
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])

            // Circle fill
            let circleRect = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
            context.setFillColor(UIColor(milestone.milestoneType.color).cgColor)
            context.fillEllipse(in: circleRect)

            // Circle border
            context.setStrokeColor(UIColor(TM.bgPrimary).cgColor)
            context.setLineWidth(2)
            context.strokeEllipse(in: circleRect)

            // Number text
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

// MARK: - Scrollable Elevation Profile View

struct ScrollableElevationProfileView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    @Binding var scrolledPointIndex: Int
    @Binding var scrollToIndex: Int?

    private let pointSpacing: CGFloat = 4
    private let maxRenderPoints: Int = 2000
    private let paddingTop: CGFloat = 20
    private let paddingBottom: CGFloat = 30

    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var lastHapticIndex: Int = 0
    @State private var profileImage: UIImage?
    @State private var activeMilestoneIndex: Int? = nil

    #if DEBUG
    @State private var fpsCounter = FPSCounter()
    #endif

    private var milestoneIndices: Set<Int> {
        Set(milestones.map(\.pointIndex))
    }

    /// Find which milestone (if any) is under the cursor
    private var currentMilestoneUnderCursor: (index: Int, milestone: Milestone)? {
        for (index, milestone) in milestones.enumerated() {
            if abs(milestone.pointIndex - scrolledPointIndex) <= 3 {
                return (index, milestone)
            }
        }
        return nil
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = geometry.size.width / 2

            ZStack {
                TM.bgSecondary

                ScrollView(.horizontal, showsIndicators: false) {
                    // Pre-rendered profile image with milestones (static)
                    if let image = profileImage {
                        Image(uiImage: image)
                            .interpolation(.none)
                    }
                }
                .scrollPosition($scrollPosition)
                .onScrollGeometryChange(for: Int.self) { geo in
                    let offset = geo.contentOffset.x
                    let index = Int(offset / pointSpacing)
                    return max(0, min(index, trackPoints.count - 1))
                } action: { oldIndex, newIndex in
                    handleIndexChange(oldIndex: oldIndex, newIndex: newIndex)
                }
                .onChange(of: scrollToIndex) { _, newIndex in
                    handleProgrammaticScroll(targetIndex: newIndex)
                }

                // Active milestone highlight (only ONE view, only when cursor is on a milestone)
                if let active = currentMilestoneUnderCursor {
                    ActiveMilestoneHighlight(
                        milestone: active.milestone,
                        index: active.index,
                        scrollOffset: CGFloat(scrolledPointIndex) * pointSpacing,
                        horizontalPadding: horizontalPadding,
                        pointSpacing: pointSpacing,
                        height: geometry.size.height,
                        paddingTop: paddingTop,
                        paddingBottom: paddingBottom,
                        trackPoints: trackPoints
                    )
                }

                // Cursor overlay
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
                            .foregroundStyle(fpsCounter.fps >= 55 ? .green : fpsCounter.fps >= 30 ? .yellow : .red)
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

    // MARK: - Index Change Handling

    private func handleIndexChange(oldIndex: Int, newIndex: Int) {
        guard newIndex != scrolledPointIndex else { return }

        let previousIndex = scrolledPointIndex
        scrolledPointIndex = newIndex

        triggerHapticIfNeeded(oldIndex: previousIndex, newIndex: newIndex)
    }

    private func triggerHapticIfNeeded(oldIndex: Int, newIndex: Int) {
        let minIdx = min(oldIndex, newIndex)
        let maxIdx = max(oldIndex, newIndex)

        let crossedMilestone = milestoneIndices.contains { idx in
            idx >= minIdx && idx <= maxIdx
        }

        if crossedMilestone {
            Haptic.medium.trigger()
            lastHapticIndex = newIndex
        } else if abs(newIndex - lastHapticIndex) >= 20 {
            Haptic.light.trigger()
            lastHapticIndex = newIndex
        }
    }

    private func handleProgrammaticScroll(targetIndex: Int?) {
        guard let targetIndex else { return }

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
    let horizontalPadding: CGFloat
    let pointSpacing: CGFloat
    let height: CGFloat
    let paddingTop: CGFloat
    let paddingBottom: CGFloat
    let trackPoints: [TrackPoint]

    @State private var isAppearing = false

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

    /// X position relative to screen center (where cursor is)
    private var xOffsetFromCenter: CGFloat {
        let milestoneX = CGFloat(milestone.pointIndex) * pointSpacing
        let cursorX = scrollOffset
        return milestoneX - cursorX
    }

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2

            ZStack {
                // Glow effect
                Circle()
                    .fill(milestone.milestoneType.color.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .blur(radius: 4)

                // Main circle
                Circle()
                    .fill(milestone.milestoneType.color)
                    .frame(width: 24, height: 24)

                // Border
                Circle()
                    .stroke(TM.bgPrimary, lineWidth: 3)
                    .frame(width: 24, height: 24)

                // Number
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isAppearing ? 1.0 : 0.5)
            .opacity(isAppearing ? 1.0 : 0.0)
            .position(x: centerX + xOffsetFromCenter, y: yPosition)
            .onAppear {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    isAppearing = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}
