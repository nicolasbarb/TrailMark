import SwiftUI
import UIKit

// MARK: - Static Profile Image Renderer (rendered once)

private struct MiniProfileImageRenderer {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let width: CGFloat
    let height: CGFloat
    let paddingH: CGFloat
    let paddingV: CGFloat

    func render() -> UIImage? {
        guard trackPoints.count >= 2 else { return nil }

        let size = CGSize(width: width, height: height)
        let plotRect = CGRect(
            x: paddingH, y: paddingV,
            width: width - paddingH * 2,
            height: height - paddingV * 2
        )

        var minEle = Double.infinity
        var maxEle = -Double.infinity
        for point in trackPoints {
            minEle = min(minEle, point.elevation)
            maxEle = max(maxEle, point.elevation)
        }
        let eleRange = max(maxEle - minEle, 1)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let gc = ctx.cgContext
            drawFill(gc: gc, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
            drawLine(gc: gc, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
            drawMilestones(gc: gc, plotRect: plotRect, minEle: minEle, eleRange: eleRange)
        }
    }

    private func drawFill(gc: CGContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        let count = trackPoints.count
        let fillPath = CGMutablePath()

        for (i, point) in trackPoints.enumerated() {
            let progress = CGFloat(i) / CGFloat(count - 1)
            let x = plotRect.minX + progress * plotRect.width
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if i == 0 {
                fillPath.move(to: CGPoint(x: x, y: plotRect.maxY))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        fillPath.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.maxY))
        fillPath.closeSubpath()

        gc.saveGState()
        gc.addPath(fillPath)
        gc.clip()

        let colors = [
            UIColor.tertiaryLabel.withAlphaComponent(0.3).cgColor,
            UIColor.tertiaryLabel.withAlphaComponent(0.05).cgColor
        ]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
        gc.drawLinearGradient(gradient, start: CGPoint(x: 0, y: plotRect.minY), end: CGPoint(x: 0, y: plotRect.maxY), options: [])
        gc.restoreGState()
    }

    private func drawLine(gc: CGContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        let count = trackPoints.count
        let linePath = CGMutablePath()

        for (i, point) in trackPoints.enumerated() {
            let progress = CGFloat(i) / CGFloat(count - 1)
            let x = plotRect.minX + progress * plotRect.width
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if i == 0 { linePath.move(to: CGPoint(x: x, y: y)) }
            else { linePath.addLine(to: CGPoint(x: x, y: y)) }
        }

        gc.addPath(linePath)
        gc.setStrokeColor(UIColor.secondaryLabel.cgColor)
        gc.setLineWidth(1.5)
        gc.setLineCap(.round)
        gc.setLineJoin(.round)
        gc.strokePath()
    }

    private func drawMilestones(gc: CGContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        let count = trackPoints.count
        for milestone in milestones {
            guard milestone.pointIndex < count else { continue }

            let progress = CGFloat(milestone.pointIndex) / CGFloat(count - 1)
            let x = plotRect.minX + progress * plotRect.width
            let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

            let dotRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
            gc.setFillColor(UIColor(milestone.milestoneType.color).cgColor)
            gc.fillEllipse(in: dotRect)
        }
    }
}

// MARK: - Mini Profile View

struct MiniProfileView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let currentIndex: Int
    let onIndexSelected: (Int) -> Void

    private let height: CGFloat = 50
    private let paddingH: CGFloat = 16
    private let paddingV: CGFloat = 8

    @State private var profileImage: UIImage?
    // Pre-computed elevation bounds (avoids O(n) per frame)
    @State private var minEle: Double = 0
    @State private var eleRange: Double = 1
    @State private var renderedSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Static profile image (rendered once)
                if let image = profileImage {
                    Image(uiImage: image)
                        .interpolation(.high)
                }

                // Cursor only (O(1) per frame)
                cursorOverlay(size: geometry.size)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = indexFromLocation(value.location.x, width: geometry.size.width)
                        onIndexSelected(index)
                    }
            )
            .onAppear {
                renderImageIfNeeded(size: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                renderImageIfNeeded(size: newSize)
            }
            .onChange(of: milestones.count) { _, _ in
                renderedSize = .zero // Force re-render
                renderImageIfNeeded(size: geometry.size)
            }
        }
        .frame(height: height)
        .background(TM.bgPrimary)
    }

    // MARK: - Cursor (O(1) — uses pre-computed bounds)

    private func cursorOverlay(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            guard currentIndex >= 0, currentIndex < trackPoints.count, trackPoints.count >= 2 else { return }

            let plotRect = CGRect(
                x: paddingH, y: paddingV,
                width: canvasSize.width - paddingH * 2,
                height: canvasSize.height - paddingV * 2
            )

            let progress = CGFloat(currentIndex) / CGFloat(trackPoints.count - 1)
            let x = plotRect.minX + progress * plotRect.width
            let y = plotRect.maxY - CGFloat((trackPoints[currentIndex].elevation - minEle) / eleRange) * plotRect.height

            // Vertical line
            var linePath = Path()
            linePath.move(to: CGPoint(x: x, y: plotRect.minY))
            linePath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(linePath, with: .color(.secondary), style: StrokeStyle(lineWidth: 1))

            // Dot
            let borderRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: borderRect), with: .color(.white))
            let dotRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dotRect), with: .color(.secondary))
        }
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private func renderImageIfNeeded(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        // Skip if size hasn't meaningfully changed (avoids re-render from sub-pixel layout shifts)
        guard abs(size.width - renderedSize.width) > 1 || abs(size.height - renderedSize.height) > 1 else { return }

        renderedSize = size

        // Pre-compute elevation bounds once
        var minE = Double.infinity
        var maxE = -Double.infinity
        for point in trackPoints {
            minE = min(minE, point.elevation)
            maxE = max(maxE, point.elevation)
        }
        minEle = minE
        eleRange = max(maxE - minE, 1)

        let renderer = MiniProfileImageRenderer(
            trackPoints: trackPoints,
            milestones: milestones,
            width: size.width,
            height: size.height,
            paddingH: paddingH,
            paddingV: paddingV
        )
        profileImage = renderer.render()
    }

    private func indexFromLocation(_ x: CGFloat, width: CGFloat) -> Int {
        let plotWidth = width - paddingH * 2
        let clampedX = max(paddingH, min(x, width - paddingH))
        let progress = (clampedX - paddingH) / plotWidth
        let index = Int(progress * CGFloat(trackPoints.count - 1))
        return max(0, min(index, trackPoints.count - 1))
    }
}
