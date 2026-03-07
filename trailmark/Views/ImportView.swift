import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct ImportView: View {
    @Bindable var store: StoreOf<ImportFeature>

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            switch store.phase {
            case .upload:
                uploadPhaseView
            case .analyzing:
                analyzingPhaseView
            case .result:
                resultPhaseView
            }
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
            Spacer()

            // Logo
            VStack(spacing: 8) {
                Text("TrailMark")
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                    .foregroundStyle(TM.accent)

                Text("ÉDITEUR DE REPÈRES GPS")
                    .font(.caption2)
                    .tracking(3)
                    .foregroundStyle(TM.textMuted)
            }

            // Upload zone
            uploadZone
                .padding(.top, 48)

            // Error message
            if let error = store.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(TM.danger)
                    .padding(.top, 12)
            }

            Spacer()

            // Back link
            Button {
                Haptic.light.trigger()
                store.send(.dismissTapped)
            } label: {
                Text("Retour à mes parcours")
                    .underline()
            }
            .tertiaryButton(size: .mini, tint: TM.textSecondary)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 28)
    }

    private var uploadZone: some View {
        Button {
            Haptic.medium.trigger()
            store.send(.uploadZoneTapped)
        } label: {
            VStack(spacing: 16) {
                // Icon
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(TM.accent)
                    .frame(width: 48, height: 48)
                    .background(TM.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                // Text
                VStack(spacing: 4) {
                    Text("Importer un fichier GPX")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TM.textPrimary)

                    Text("Appuyez pour parcourir")
                        .font(.caption)
                        .foregroundStyle(TM.textMuted)
                }

                // Badge
                Text(".GPX")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(TM.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(TM.accent.opacity(0.1), in: Capsule())
            }
            .frame(maxWidth: 300)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundStyle(TM.border)
            )
        }
    }

    // MARK: - Analyzing Phase

    private var analyzingPhaseView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(TM.accent)

            VStack(spacing: 8) {
                Text("Analyse du parcours")
                    .font(.headline)
                    .foregroundStyle(TM.textPrimary)

                Text("Détection des repères en cours...")
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
            }

            Spacer()
        }
    }

    // MARK: - Result Phase

    private var resultPhaseView: some View {
        VStack(spacing: 0) {
            // Header
            resultHeader
                .padding(.top, 20)
                .padding(.horizontal, 20)

            // Elevation profile (blurred for free users)
            elevationProfileSection
                .padding(.top, 24)

            // Milestones count
            milestonesCountSection
                .padding(.top, 20)
                .padding(.horizontal, 20)

            Spacer()

            // Action buttons
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
    }

    private var resultHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(TM.success)

            Text("Parcours importé")
                .font(.headline)
                .foregroundStyle(TM.textPrimary)

            if let trail = store.parsedTrail {
                Text(trail.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TM.accent)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Label(String(format: "%.1f km", trail.distance / 1000), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    Label("D+ \(trail.dPlus)m", systemImage: "arrow.up.right")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(TM.textMuted)
            }
        }
    }

    private var elevationProfileSection: some View {
        ZStack {
            // Profile view
            ElevationProfilePreview(
                trackPoints: store.parsedTrackPoints,
                milestones: store.detectedMilestones
            )
            .frame(height: 150)

            // Blur overlay for free users
            if !store.isPremium && !store.detectedMilestones.isEmpty {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: 3)

                // Lock icon
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(TM.textMuted)

                    Text("Aperçu verrouillé")
                        .font(.caption)
                        .foregroundStyle(TM.textMuted)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private var milestonesCountSection: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(TM.accent)

            if store.detectedMilestones.isEmpty {
                Text("Aucun repère détecté")
                    .foregroundStyle(TM.textMuted)
            } else {
                Text("\(store.detectedMilestones.count) repères détectés automatiquement")
                    .foregroundStyle(TM.textPrimary)
            }

            Spacer()
        }
        .font(.subheadline)
        .padding(16)
        .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if store.detectedMilestones.isEmpty {
            // No milestones detected - single button
            Button {
                Haptic.medium.trigger()
                store.send(.skipTapped)
            } label: {
                Text("Continuer")
            }
            .primaryButton(size: .large, width: .flexible, shape: .capsule)
        } else if store.isPremium {
            // Premium user - show continue and ignore buttons
            VStack(spacing: 12) {
                Button {
                    Haptic.medium.trigger()
                    store.send(.continueWithMilestonesTapped)
                } label: {
                    Text("Continuer")
                }
                .primaryButton(size: .large, width: .flexible, shape: .capsule)

                Button {
                    Haptic.light.trigger()
                    store.send(.skipTapped)
                } label: {
                    Text("Ignorer et placer manuellement")
                        .underline()
                }
                .tertiaryButton(size: .small, tint: .secondary)
            }
        } else {
            // Free user - show unlock and manual buttons
            VStack(spacing: 12) {
                Button {
                    Haptic.medium.trigger()
                    store.send(.unlockTapped)
                } label: {
                    Label {
                        Text("Débloquer la détection auto")
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
                .primaryButton(size: .large, width: .flexible, shape: .capsule)

                Button {
                    Haptic.light.trigger()
                    store.send(.skipTapped)
                } label: {
                    Text("Placer mes repères manuellement")
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
        store: Store(initialState: ImportFeature.State()) {
            ImportFeature()
        }
    )
}

#Preview("Result - Free") {
    ImportView(
        store: Store(
            initialState: ImportFeature.State(
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
                    Milestone(trailId: 0, pointIndex: 0, latitude: 0, longitude: 0, elevation: 100, distance: 0, type: .montee, message: "Test"),
                    Milestone(trailId: 0, pointIndex: 100, latitude: 0, longitude: 0, elevation: 500, distance: 5000, type: .descente, message: "Test")
                ],
                isPremium: false
            )
        ) {
            ImportFeature()
        }
    )
}

#Preview("Result - Premium") {
    ImportView(
        store: Store(
            initialState: ImportFeature.State(
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
                    Milestone(trailId: 0, pointIndex: 0, latitude: 0, longitude: 0, elevation: 100, distance: 0, type: .montee, message: "Test"),
                    Milestone(trailId: 0, pointIndex: 100, latitude: 0, longitude: 0, elevation: 500, distance: 5000, type: .descente, message: "Test")
                ],
                isPremium: true
            )
        ) {
            ImportFeature()
        }
    )
}
