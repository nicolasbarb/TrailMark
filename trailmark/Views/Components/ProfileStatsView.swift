import SwiftUI

// MARK: - Pre-computed Profile Data

/// Pre-computes all expensive stats once for O(1) lookups during scroll
final class ProfileStatsData {
    let trackPoints: [TrackPoint]

    // Pre-computed arrays (one value per track point)
    let cumulativeDPlus: [Int]
    let cumulativeDMinus: [Int]
    let slopePercent: [Int]
    let terrainTypes: [TerrainType]
    let segmentIndices: [Int] // Maps each point to its segment index
    let segments: [SegmentData]

    init(trackPoints: [TrackPoint]) {
        self.trackPoints = trackPoints

        // Pre-compute cumulative D+ and D-
        var dPlusArray = [Int]()
        var dMinusArray = [Int]()
        dPlusArray.reserveCapacity(trackPoints.count)
        dMinusArray.reserveCapacity(trackPoints.count)

        var runningDPlus: Double = 0
        var runningDMinus: Double = 0

        for i in 0..<trackPoints.count {
            if i > 0 {
                let delta = trackPoints[i].elevation - trackPoints[i - 1].elevation
                if delta > 0 {
                    runningDPlus += delta
                } else {
                    runningDMinus += abs(delta)
                }
            }
            dPlusArray.append(Int(runningDPlus))
            dMinusArray.append(Int(runningDMinus))
        }

        self.cumulativeDPlus = dPlusArray
        self.cumulativeDMinus = dMinusArray

        // Pre-compute slopes using ElevationProfileAnalyzer
        var slopes = [Int]()
        slopes.reserveCapacity(trackPoints.count)

        for i in 0..<trackPoints.count {
            let slope = ElevationProfileAnalyzer.computeSlope(at: i, trackPoints: trackPoints)
            slopes.append(Int(slope * 100))
        }
        self.slopePercent = slopes

        // Pre-compute terrain types using ElevationProfileAnalyzer
        let rawTerrainTypes = ElevationProfileAnalyzer.classify(trackPoints: trackPoints)
        self.terrainTypes = rawTerrainTypes

        // Pre-compute segments
        var segmentList = [SegmentData]()
        var segmentIndexMap = [Int](repeating: 0, count: trackPoints.count)

        guard !rawTerrainTypes.isEmpty else {
            self.segments = []
            self.segmentIndices = []
            return
        }

        var i = 0
        while i < trackPoints.count {
            let segmentStart = i
            let segmentType = rawTerrainTypes[i]

            // Find end of segment
            var segmentEnd = i
            while segmentEnd < trackPoints.count - 1 && rawTerrainTypes[segmentEnd + 1] == segmentType {
                segmentEnd += 1
            }

            let startPoint = trackPoints[segmentStart]
            let endPoint = trackPoints[segmentEnd]
            let distance = endPoint.distance - startPoint.distance
            let elevationChange = endPoint.elevation - startPoint.elevation
            let avgSlope = distance > 0 ? Int(abs(elevationChange / distance) * 100) : 0

            let milestoneType: MilestoneType
            switch segmentType {
            case .climbing: milestoneType = .climb
            case .descending: milestoneType = .descent
            case .flat: milestoneType = .flat
            }

            let segment = SegmentData(
                startIndex: segmentStart,
                endIndex: segmentEnd,
                type: milestoneType,
                distance: distance,
                elevationChange: Int(abs(elevationChange)),
                avgSlopePercent: avgSlope
            )
            segmentList.append(segment)

            // Map all points in this segment to segment index
            let segmentIdx = segmentList.count - 1
            for j in segmentStart...segmentEnd {
                segmentIndexMap[j] = segmentIdx
            }

            i = segmentEnd + 1
        }

        self.segments = segmentList
        self.segmentIndices = segmentIndexMap
    }

    struct SegmentData {
        let startIndex: Int
        let endIndex: Int
        let type: MilestoneType
        let distance: Double
        let elevationChange: Int
        let avgSlopePercent: Int
    }
}

// MARK: - Profile Stats View (iOS 26 Liquid Glass Design)

struct ProfileStatsView: View {
    let statsData: ProfileStatsData
    let currentIndex: Int
    let milestones: [Milestone]
    var onGoToMilestone: ((Milestone) -> Void)?
    var onEditMilestone: ((Milestone) -> Void)?
    var onScrolledToMilestone: ((Milestone) -> Void)?

    private var currentPoint: TrackPoint {
        statsData.trackPoints[currentIndex]
    }

    private var slopePercent: Int {
        statsData.slopePercent[currentIndex]
    }

    private var terrainType: TerrainType {
        statsData.terrainTypes[currentIndex]
    }

    private var currentSegment: ProfileStatsData.SegmentData? {
        let segmentIdx = statsData.segmentIndices[currentIndex]
        guard segmentIdx < statsData.segments.count else { return nil }
        return statsData.segments[segmentIdx]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            if milestones.isEmpty {
                emptyState
            } else {
                MilestoneCarousel(
                    milestones: milestones,
                    currentDistance: currentPoint.distance,
                    currentPointIndex: currentIndex,
                    onGoToMilestone: onGoToMilestone,
                    onEditMilestone: onEditMilestone,
                    onScrolledToMilestone: onScrolledToMilestone
                )
                .padding(.horizontal, -16) // Break out of parent padding
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 20) {
                // Stacked milestone type icons as decoration
                HStack(spacing: 8) {
                    ForEach([MilestoneType.climb, .descent, .aidStation, .danger, .info], id: \.self) { type in
                        Image(systemName: type.systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(type.color.opacity(0.5))
                            .frame(width: 28, height: 28)
                            .glassEffect(.regular, in: Circle())
                    }
                }

                VStack(spacing: 6) {
                    Text("Aucun repère")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(TM.textPrimary)

                    Text("Place tes repères sur le profil\npour préparer ta stratégie de course.")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(TM.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }

            Spacer()

            // Chevron pointing down to the button
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(TM.textTertiary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Terrain Segment Card

    private func kineticTape(segment: ProfileStatsData.SegmentData) -> some View {
        HStack(spacing: 0) {
            // Left: Icon block
            VStack(spacing: 3) {
                Image(systemName: segment.type.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(segment.type.color)
                    .frame(width: 20, height: 20)

                Text(segment.type.label.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(segment.type.color.opacity(0.85))
                    .frame(height: 10)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(slopePercent > 0 ? "+" : "")\(slopePercent)")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                    Text("%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(TM.textPrimary)
            }
            .frame(width: 80)
            .frame(maxHeight: .infinity)

            // Right: Stats (receipt style)
            VStack(spacing: 6) {
                statRow("SEGMENT", value: formatSegmentDistance(segment.distance))
                statRow("D\(segment.type == .descent ? "−" : "+")", value: "\(segment.elevationChange)m")
                statRow("PENTE MOY", value: "\(segment.avgSlopePercent)%", valueColor: segment.type.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func statRow(_ label: String, value: String, valueColor: Color = TM.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(TM.textMuted)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(valueColor)
        }
    }

    private func formatSegmentDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return "\(Int(distance)) m"
        }
    }
}

// MARK: - Milestone Carousel

private struct MilestoneCarousel: View {
    let milestones: [Milestone]
    let currentDistance: Double
    let currentPointIndex: Int
    var onGoToMilestone: ((Milestone) -> Void)?
    var onEditMilestone: ((Milestone) -> Void)?
    var onScrolledToMilestone: ((Milestone) -> Void)?

    @State private var scrollPosition: Int?
    @State private var isProgrammaticScroll = false
    @State private var suppressCursorSync = false
    @State private var suppressGeneration = 0

    private let passedMargin = 5

    private var cursorTargetIndex: Int {
        let target = milestones.firstIndex { $0.pointIndex + passedMargin > currentPointIndex }
        return target ?? (milestones.count - 1)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                    milestoneCard(milestone, number: index + 1)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition)
        .contentMargins(.horizontal, 16)
        .scrollClipDisabled()
        .frame(maxHeight: .infinity)
        .onChange(of: cursorTargetIndex) { _, newTarget in
            guard !suppressCursorSync else { return }
            isProgrammaticScroll = true
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                scrollPosition = newTarget
            }
        }
        .onChange(of: scrollPosition) { _, newPosition in
            guard let index = newPosition, index < milestones.count else { return }
            if isProgrammaticScroll {
                isProgrammaticScroll = false
                return
            }
            // User swiped — suppress cursor-driven auto-scroll to avoid feedback loop
            suppressCursorSync = true
            suppressGeneration += 1
            let generation = suppressGeneration
            onScrolledToMilestone?(milestones[index])
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                if suppressGeneration == generation {
                    suppressCursorSync = false
                }
            }
        }
        .onAppear {
            isProgrammaticScroll = true
            scrollPosition = cursorTargetIndex
        }
    }

    private func milestoneCard(_ milestone: Milestone, number: Int) -> some View {
        let distanceToMilestone = milestone.distance - currentDistance
        let displayName = (milestone.name?.isEmpty == false) ? milestone.name! : "Repère \(number)"
        let absDist = abs(distanceToMilestone)
        let isOnMilestone = absDist < 30
        let isAhead = distanceToMilestone > 0

        return VStack(alignment: .leading, spacing: 8) {
            // Header: type · distance
            HStack(spacing: 4) {
                Image(systemName: milestone.milestoneType.systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(milestone.milestoneType.color)
                if isOnMilestone {
                    Text(milestone.milestoneType.label)
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(TM.textSecondary)
                } else {
                    Text("\(milestone.milestoneType.label) · \(isAhead ? "Dans" : "Il y a") \(formatDistance(absDist))")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(TM.textSecondary)
                }
            }

            // Name
            Text(displayName)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(TM.textPrimary)

            // Message
            Text(milestone.message)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(TM.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    onGoToMilestone?(milestone)
                } label: {
                    Label("Voir", systemImage: "eye")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(TM.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                }

                Button {
                    onEditMilestone?(milestone)
                } label: {
                    Label("Modifier", systemImage: "pencil")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(TM.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return "\(Int(meters)) m"
        }
    }
}

