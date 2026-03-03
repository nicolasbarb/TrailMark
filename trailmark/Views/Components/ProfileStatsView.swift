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
            case .climbing: milestoneType = .montee
            case .descending: milestoneType = .descente
            case .flat: milestoneType = .plat
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

    private var currentPoint: TrackPoint {
        statsData.trackPoints[currentIndex]
    }

    // O(1) lookups from pre-computed data
    private var slopePercent: Int {
        statsData.slopePercent[currentIndex]
    }

    private var terrainType: TerrainType {
        statsData.terrainTypes[currentIndex]
    }

    private var cumulativeDPlus: Int {
        statsData.cumulativeDPlus[currentIndex]
    }

    private var cumulativeDMinus: Int {
        statsData.cumulativeDMinus[currentIndex]
    }

    private var currentSegment: ProfileStatsData.SegmentData? {
        let segmentIdx = statsData.segmentIndices[currentIndex]
        guard segmentIdx < statsData.segments.count else { return nil }
        return statsData.segments[segmentIdx]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // HERO: Terrain Segment Card (Important: Slope, Distance in segment, Terrain type)
            if let segment = currentSegment {
                terrainSegmentCard(segment: segment)
            }

            // SECONDARY: Distance from start
            distanceCard

            // TERTIARY: Altitude, D+, D- grid
            secondaryStatsGrid
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Hero: Terrain Segment Card

    private func terrainSegmentCard(segment: ProfileStatsData.SegmentData) -> some View {
        VStack(spacing: 0) {
            // Top row: Terrain type + Slope
            HStack(alignment: .top) {
                // Terrain indicator
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.type.icon)
                        .font(.system(size: 28))

                    Text(segment.type.label.uppercased())
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(segment.type.color)
                }

                Spacer()

                // Large slope display
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(slopePercent > 0 ? "+" : "")\(slopePercent)")
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundStyle(segment.type.color)
                        Text("%")
                            .font(.system(.title3, design: .monospaced, weight: .medium))
                            .foregroundStyle(segment.type.color.opacity(0.7))
                    }
                    Text("PENTE")
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(TM.textMuted)
                }
            }

            Spacer().frame(height: 16)

            // Segment stats row
            HStack(spacing: 0) {
                // Segment distance
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEGMENT")
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(TM.textMuted)
                    Text(formatSegmentDistance(segment.distance))
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.textPrimary)
                }

                Spacer()

                // Elevation change
                VStack(alignment: .center, spacing: 2) {
                    Text("D\(segment.type == .descente ? "-" : "+")")
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(TM.textMuted)
                    Text("\(segment.elevationChange)m")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.textPrimary)
                }

                Spacer()

                // Average slope
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MOY")
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(TM.textMuted)
                    Text("\(segment.avgSlopePercent)%")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.textPrimary)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(segment.type.color.opacity(0.08))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    segment.type.color.opacity(0.4),
                                    segment.type.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
    }

    // MARK: - Secondary: Distance Card

    private var distanceCard: some View {
        HStack {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 20))
                .foregroundStyle(TM.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("DISTANCE PARCOURUE")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(TM.textMuted)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", currentPoint.distance / 1000))
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.textPrimary)
                    Text("km")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(TM.textMuted)
                }
            }

            Spacer()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(TM.border.opacity(0.5), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Tertiary: Secondary Stats Grid

    private var secondaryStatsGrid: some View {
        HStack(spacing: 10) {
            // Altitude
            compactStatCard(
                icon: "mountain.2",
                label: "ALTITUDE",
                value: "\(Int(currentPoint.elevation))",
                unit: "m",
                color: TM.textPrimary
            )

            // D+ done
            compactStatCard(
                icon: "arrow.up.right",
                label: "D+ FAIT",
                value: "\(cumulativeDPlus)",
                unit: "m",
                color: MilestoneType.montee.color
            )

            // D- done
            compactStatCard(
                icon: "arrow.down.right",
                label: "D- FAIT",
                value: "\(cumulativeDMinus)",
                unit: "m",
                color: MilestoneType.descente.color
            )
        }
    }

    private func compactStatCard(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color.opacity(0.8))

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.textMuted)
                }

                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TM.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(TM.border.opacity(0.3), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Helpers

    private func formatSegmentDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return "\(Int(distance)) m"
        }
    }
}
