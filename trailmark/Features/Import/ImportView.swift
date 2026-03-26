import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct ImportView: View {
    @Bindable var store: StoreOf<ImportStore>

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [TM.accent.opacity(0.08), TM.bgSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                switch store.phase {
                case .upload:
                    uploadPhaseView
                case .analyzing:
                    analyzingPhaseView
                case .result:
                    resultPhaseView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close", systemImage: "xmark", role: .cancel) {
                        Haptic.light.trigger()
                        store.send(.dismissTapped)
                    }
                }
            }
            .toolbar(store.phase == .analyzing ? .hidden : .visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(store.phase == .analyzing)
        .fileImporter(
            isPresented: Binding(
                get: { store.isShowingFilePicker },
                set: { newValue in
                    if !newValue {
                        store.send(.filePickerDismissed)
                    }
                }
            ),
            allowedContentTypes: gpxContentTypes,
            onCompletion: { result in
                switch result {
                case .success(let url):
                    store.send(.fileSelected(url.path))
                case .failure:
                    store.send(.filePickerDismissed)
                }
            }
        )
        .fullScreenCover(
            item: $store.scope(state: \.paywall, action: \.paywall)
        ) { paywallStore in
            PaywallContainerView(store: paywallStore)
        }
    }

    // MARK: - Upload Phase

    private var uploadPhaseView: some View {
        VStack(spacing: 0) {
            // Pills en haut
            trailPillsView
                .padding(.top, 16)

//            Spacer()

            // Texte centré
            VStack(spacing: 8) {
                Text("import.upload.title")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TM.textPrimary)
                    .multilineTextAlignment(.center)

                Text("import.upload.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(TM.textMuted)
                    .multilineTextAlignment(.center)

                // Error message
                if let error = store.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TM.danger)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 28)

            Spacer()

            // CTA en bas
            Button {
                Haptic.medium.trigger()
                store.send(.uploadZoneTapped)
            } label: {
                Text("import.upload.cta")
            }
            .primaryButton(size: .large, width: .flexible, shape: .capsule)
            .padding(.horizontal, 24)

            Text("import.upload.sources")
                .font(.caption)
                .foregroundStyle(TM.textMuted)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Trail Pills

    private static let trailNames: [[String]] = [
        ["UTMB", "Tour du Mont Blanc", "Diagonale des Fous", "CCC", "Échappée Belle"],
        ["Western States", "Tor des Géants", "SaintéLyon", "Templiers", "Pikes Peak"],
        ["Lavaredo", "Transgrancanaria", "Hardrock 100", "Eiger Ultra Trail", "GR20"],
        ["Cape Town Ultra", "Trail du Ventoux", "Oman by UTMB", "Patagonia Run", "MiUT"],
    ]

    private static let pillConfigs: [(reversed: Bool, duration: Double, startOffset: CGFloat)] = [
        (false, 25, 0),
        (true, 32, -60),
        (false, 28, -120),
        (true, 26, -40),
    ]

    private var trailPillsView: some View {
        VStack(spacing: 8) {
            ForEach(Array(Self.trailNames.enumerated()), id: \.offset) { index, row in
                let config = Self.pillConfigs[index]
                ScrollingPillRow(
                    names: row,
                    reversed: config.reversed,
                    duration: config.duration,
                    startOffset: config.startOffset
                )
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.1),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Analyzing Phase

    private var analyzingPhaseView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(TM.accent)

            VStack(spacing: 8) {
                Text("import.analyzing.title")
                    .font(.headline)
                    .foregroundStyle(TM.textPrimary)

                Text("import.analyzing.subtitle")
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
            }

            Spacer()
        }
    }

    // MARK: - Result Phase

    private var hasMilestones: Bool {
        !store.detectedMilestones.isEmpty
    }

    private var resultPhaseView: some View {
        VStack(spacing: 0) {
            // Header with sparkles
            resultHeader
                .padding(.top, 24)
                .padding(.horizontal, 20)

            // Elevation profile
            elevationProfileSection
                .padding(.top, 20)

            // Explanation text
            if hasMilestones {
                Text("import.result.explanation")
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Action buttons
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
    }

    private var resultHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(TM.accent)

            VStack(alignment: .leading, spacing: 4) {
                if hasMilestones {
                    Text("import.result.foundMilestones \(store.detectedMilestones.count)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(TM.textPrimary)
                } else {
                    Text("import.result.imported")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(TM.textPrimary)
                }

                if let trail = store.parsedTrail {
                    Text(trail.name)
                        .font(.subheadline)
                        .foregroundStyle(TM.textMuted)

                    HStack(spacing: 12) {
                        Text(String(format: "%.1f km", trail.distance / 1000))
                        Text("D+ \(trail.dPlus)m")
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TM.textMuted)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
    }

    private var elevationProfileSection: some View {
        ZStack(alignment: .topTrailing) {
            ElevationProfilePreview(
                trackPoints: store.parsedTrackPoints,
                milestones: store.detectedMilestones
            )
            .frame(height: 150)

            // PRO badge for free users with detected milestones
            if !store.isPremium && hasMilestones {
                ProBadge()
                    .padding(8)
            }
        }
        .background(TM.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if !hasMilestones {
            // No milestones detected - single button
            Button {
                Haptic.medium.trigger()
                store.send(.skipTapped)
            } label: {
                Text("common.continue")
            }
            .primaryButton(size: .large, width: .flexible, shape: .capsule)
        } else if store.isPremium {
            // Premium user
            VStack(spacing: 12) {
                Button {
                    Haptic.medium.trigger()
                    store.send(.continueWithMilestonesTapped)
                } label: {
                    Text("common.continue")
                }
                .primaryButton(size: .large, width: .flexible, shape: .capsule)

                Button {
                    Haptic.light.trigger()
                    store.send(.skipTapped)
                } label: {
                    Text("import.result.skipButton")
                        .underline()
                }
                .tertiaryButton(size: .small, tint: .secondary)
            }
        } else {
            // Free user
            VStack(spacing: 12) {
                Button {
                    Haptic.medium.trigger()
                    store.send(.unlockTapped)
                } label: {
                    Label {
                        Text("import.result.unlockDetection")
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                }
                .primaryButton(size: .large, width: .flexible, shape: .capsule)

                Button {
                    Haptic.light.trigger()
                    store.send(.skipTapped)
                } label: {
                    Text("import.result.manualButton")
                        .underline()
                }
                .tertiaryButton(size: .small, tint: .secondary)
            }
        }
    }

    // MARK: - Content Types

    private var gpxContentTypes: [UTType] {
        var types: [UTType] = [.xml]
        if let gpxType = UTType(filenameExtension: "gpx") {
            types.insert(gpxType, at: 0)
        }
        return types
    }
}

// MARK: - Elevation Profile Preview (simplified, non-interactive)

// MARK: - Scrolling Pill Row

private struct ScrollingPillRow: View {
    let names: [String]
    let reversed: Bool
    let duration: Double
    let startOffset: CGFloat

    @State private var contentWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let progress = CGFloat(time.truncatingRemainder(dividingBy: duration)) / CGFloat(duration)
                let shift = reversed
                    ? -contentWidth + progress * contentWidth + startOffset
                    : startOffset - progress * contentWidth

                HStack(spacing: 8) {
                    pillContent
                    pillContent
                }
                .fixedSize()
                .offset(x: shift)
            }
        }
        .frame(height: 40)
        .clipped()
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

// MARK: - Elevation Profile Preview

private struct ElevationProfilePreview: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]

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

        // Use shared ElevationProfileAnalyzer
        let terrainTypes = ElevationProfileAnalyzer.classify(trackPoints: trackPoints)

        // Draw colored segments
        drawColoredSegments(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange, maxDist: maxDist, terrainTypes: terrainTypes)

        // Draw milestone markers
        drawMilestones(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange, maxDist: maxDist)
    }

    private func drawColoredSegments(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double, maxDist: Double, terrainTypes: [TerrainType]) {
        guard trackPoints.count >= 2 else { return }

        for i in 1..<trackPoints.count {
            let prevPoint = trackPoints[i - 1]
            let currPoint = trackPoints[i]
            let terrain = terrainTypes[i]

            let x1 = plotRect.minX + CGFloat(prevPoint.distance / maxDist) * plotRect.width
            let y1 = plotRect.maxY - CGFloat((prevPoint.elevation - minEle) / eleRange) * plotRect.height
            let x2 = plotRect.minX + CGFloat(currPoint.distance / maxDist) * plotRect.width
            let y2 = plotRect.maxY - CGFloat((currPoint.elevation - minEle) / eleRange) * plotRect.height

            // Draw fill for this segment
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: x1, y: plotRect.maxY))
            fillPath.addLine(to: CGPoint(x: x1, y: y1))
            fillPath.addLine(to: CGPoint(x: x2, y: y2))
            fillPath.addLine(to: CGPoint(x: x2, y: plotRect.maxY))
            fillPath.closeSubpath()

            context.fill(fillPath, with: .color(terrain.color.opacity(0.2)))

            // Draw line for this segment
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

            // Dashed line down
            var dashPath = Path()
            dashPath.move(to: CGPoint(x: x, y: y))
            dashPath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(dashPath, with: .color(TM.accent.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

            // Circle background
            let circleRect = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: circleRect), with: .color(milestone.milestoneType.color))

            // Circle border
            context.stroke(Path(ellipseIn: circleRect), with: .color(TM.bgPrimary), lineWidth: 1.5)

            // Number
            let text = Text("\(index + 1)")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            context.draw(text, at: CGPoint(x: x, y: y), anchor: .center)
        }
    }
}

#Preview("Upload") {
    ImportView(
        store: Store(initialState: ImportStore.State()) {
            ImportStore()
        }
    )
}

#Preview("Result - Free") {
    ImportView(
        store: Store(
            initialState: ImportStore.State(
                phase: .result,
                parsedTrail: Trail(
                    id: nil,
                    name: "Col de la Croix",
                    createdAt: Date(),
                    distance: 12400,
                    dPlus: 620
                ),
                parsedTrackPoints: [],
                detectedMilestones: [
                    Milestone(trailId: 0, pointIndex: 0, latitude: 0, longitude: 0, elevation: 100, distance: 0, type: .climb, message: "Test"),
                    Milestone(trailId: 0, pointIndex: 100, latitude: 0, longitude: 0, elevation: 500, distance: 5000, type: .descent, message: "Test")
                ],
                isPremium: false
            )
        ) {
            ImportStore()
        }
    )
}

#Preview("Result - Premium") {
    ImportView(
        store: Store(
            initialState: ImportStore.State(
                phase: .result,
                parsedTrail: Trail(
                    id: nil,
                    name: "Col de la Croix",
                    createdAt: Date(),
                    distance: 12400,
                    dPlus: 620
                ),
                parsedTrackPoints: [],
                detectedMilestones: [
                    Milestone(trailId: 0, pointIndex: 0, latitude: 0, longitude: 0, elevation: 100, distance: 0, type: .climb, message: "Test"),
                    Milestone(trailId: 0, pointIndex: 100, latitude: 0, longitude: 0, elevation: 500, distance: 5000, type: .descent, message: "Test")
                ],
                isPremium: true
            )
        ) {
            ImportStore()
        }
    )
}
