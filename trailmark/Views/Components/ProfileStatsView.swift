import SwiftUI

// MARK: - Profile Stats View

struct ProfileStatsView: View {
    let trackPoints: [TrackPoint]
    let currentIndex: Int

    // Terrain detection settings (same as profile renderer)
    private let slopeThreshold: Double = 0.05
    private let slopeWindowSize: Double = 500
    private let minSegmentLength: Double = 200

    private var currentPoint: TrackPoint {
        trackPoints[currentIndex]
    }

    // MARK: - Computed Stats

    private var currentSlope: Double {
        guard currentIndex > 0 else { return 0 }

        // Use a window for smoother slope calculation
        let windowDistance: Double = 100 // 100m window
        var startIdx = currentIndex
        var endIdx = currentIndex

        let currentDistance = trackPoints[currentIndex].distance

        // Find start of window
        for i in (0..<currentIndex).reversed() {
            if currentDistance - trackPoints[i].distance <= windowDistance / 2 {
                startIdx = i
            } else {
                break
            }
        }

        // Find end of window
        for i in (currentIndex + 1)..<trackPoints.count {
            if trackPoints[i].distance - currentDistance <= windowDistance / 2 {
                endIdx = i
            } else {
                break
            }
        }

        let startPoint = trackPoints[startIdx]
        let endPoint = trackPoints[endIdx]
        let distanceDelta = endPoint.distance - startPoint.distance

        guard distanceDelta > 0 else { return 0 }
        return (endPoint.elevation - startPoint.elevation) / distanceDelta
    }

    private var slopePercent: Int {
        Int(currentSlope * 100)
    }

    private var terrainType: TerrainType {
        if currentSlope > slopeThreshold {
            return .climbing
        } else if currentSlope < -slopeThreshold {
            return .descending
        } else {
            return .flat
        }
    }

    private var cumulativeDPlus: Int {
        guard currentIndex > 0 else { return 0 }
        var dPlus: Double = 0
        for i in 1...currentIndex {
            let delta = trackPoints[i].elevation - trackPoints[i - 1].elevation
            if delta > 0 {
                dPlus += delta
            }
        }
        return Int(dPlus)
    }

    private var cumulativeDMinus: Int {
        guard currentIndex > 0 else { return 0 }
        var dMinus: Double = 0
        for i in 1...currentIndex {
            let delta = trackPoints[i].elevation - trackPoints[i - 1].elevation
            if delta < 0 {
                dMinus += abs(delta)
            }
        }
        return Int(dMinus)
    }

    private var currentSegmentInfo: SegmentInfo? {
        computeCurrentSegment()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Main stats (Altitude, Distance, Slope)
            HStack(spacing: 0) {
                statItem(label: "ALTITUDE", value: "\(Int(currentPoint.elevation))", unit: "m")
                Divider().frame(height: 30)
                statItem(label: "DISTANCE", value: String(format: "%.2f", currentPoint.distance / 1000), unit: "km")
                Divider().frame(height: 30)
                statItem(
                    label: "PENTE",
                    value: "\(slopePercent > 0 ? "+" : "")\(slopePercent)",
                    unit: "%",
                    color: terrainType.color
                )
            }

            // Row 2: D+ / D- cumulated
            HStack(spacing: 0) {
                statItem(label: "D+ FAIT", value: "\(cumulativeDPlus)", unit: "m", color: MilestoneType.montee.color)
                Divider().frame(height: 30)
                statItem(label: "D- FAIT", value: "\(cumulativeDMinus)", unit: "m", color: MilestoneType.descente.color)
            }

            // Row 3: Current segment info
            if let segment = currentSegmentInfo {
                segmentInfoView(segment: segment)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    // MARK: - Stat Item

    private func statItem(label: String, value: String, unit: String, color: Color = TM.textPrimary) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(TM.textMuted)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(TM.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Segment Info View

    private func segmentInfoView(segment: SegmentInfo) -> some View {
        HStack(spacing: 8) {
            // Terrain type indicator
            Text(segment.type.icon)
                .font(.title3)

            // Segment description
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.type.label.uppercased())
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(segment.type.color)

                Text(segment.description)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TM.textSecondary)
            }

            Spacer()

            // Progress in segment
            VStack(alignment: .trailing, spacing: 2) {
                Text("PROGRESSION")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(TM.textMuted)
                Text("\(segment.progressPercent)%")
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(segment.type.color)
            }
        }
        .padding(12)
        .background(segment.type.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(segment.type.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Segment Computation

    private func computeCurrentSegment() -> SegmentInfo? {
        guard trackPoints.count >= 2 else { return nil }

        // Compute terrain types for all points (simplified version)
        let terrainTypes = computeTerrainTypes()
        guard currentIndex < terrainTypes.count else { return nil }

        let currentTerrain = terrainTypes[currentIndex]

        // Find segment boundaries
        var segmentStart = currentIndex
        var segmentEnd = currentIndex

        // Find start of segment
        while segmentStart > 0 && terrainTypes[segmentStart - 1] == currentTerrain {
            segmentStart -= 1
        }

        // Find end of segment
        while segmentEnd < trackPoints.count - 1 && terrainTypes[segmentEnd + 1] == currentTerrain {
            segmentEnd += 1
        }

        let startPoint = trackPoints[segmentStart]
        let endPoint = trackPoints[segmentEnd]

        let segmentDistance = endPoint.distance - startPoint.distance
        let segmentElevationChange = endPoint.elevation - startPoint.elevation

        // Calculate progress within segment
        let progressDistance = trackPoints[currentIndex].distance - startPoint.distance
        let progressPercent = segmentDistance > 0 ? Int((progressDistance / segmentDistance) * 100) : 0

        // Calculate average slope
        let avgSlope = segmentDistance > 0 ? Int(abs(segmentElevationChange / segmentDistance) * 100) : 0

        // Build description
        let elevationChange = Int(abs(segmentElevationChange))
        let distanceKm = segmentDistance / 1000

        let description: String
        if distanceKm >= 1 {
            description = "\(elevationChange)m sur \(String(format: "%.1f", distanceKm))km • \(avgSlope)% moy"
        } else {
            description = "\(elevationChange)m sur \(Int(segmentDistance))m • \(avgSlope)% moy"
        }

        let milestoneType: MilestoneType
        switch currentTerrain {
        case .climbing: milestoneType = .montee
        case .descending: milestoneType = .descente
        case .flat: milestoneType = .plat
        }

        return SegmentInfo(
            type: milestoneType,
            description: description,
            progressPercent: progressPercent
        )
    }

    private func computeTerrainTypes() -> [TerrainType] {
        guard trackPoints.count >= 2 else { return [] }

        var terrainTypes = [TerrainType](repeating: .flat, count: trackPoints.count)
        let halfWindow = slopeWindowSize / 2

        // First pass: compute raw terrain types
        for i in 0..<trackPoints.count {
            let currentPoint = trackPoints[i]
            let currentDistance = currentPoint.distance

            var startIdx = i
            var endIdx = i

            for j in (0..<i).reversed() {
                if currentDistance - trackPoints[j].distance <= halfWindow {
                    startIdx = j
                } else {
                    break
                }
            }

            for j in (i + 1)..<trackPoints.count {
                if trackPoints[j].distance - currentDistance <= halfWindow {
                    endIdx = j
                } else {
                    break
                }
            }

            let startPoint = trackPoints[startIdx]
            let endPoint = trackPoints[endIdx]

            let distanceDelta = endPoint.distance - startPoint.distance
            guard distanceDelta > 0 else {
                terrainTypes[i] = .flat
                continue
            }

            let slope = (endPoint.elevation - startPoint.elevation) / distanceDelta

            if slope > slopeThreshold {
                terrainTypes[i] = .climbing
            } else if slope < -slopeThreshold {
                terrainTypes[i] = .descending
            } else {
                terrainTypes[i] = .flat
            }
        }

        // Second pass: remove small segments
        var i = 0
        while i < trackPoints.count {
            let segmentStart = i
            let segmentType = terrainTypes[i]

            var segmentEnd = i
            while segmentEnd < trackPoints.count && terrainTypes[segmentEnd] == segmentType {
                segmentEnd += 1
            }

            let segmentLength = trackPoints[min(segmentEnd, trackPoints.count - 1)].distance - trackPoints[segmentStart].distance

            if segmentLength < minSegmentLength && segmentStart > 0 {
                let prevType = terrainTypes[segmentStart - 1]
                for j in segmentStart..<segmentEnd {
                    terrainTypes[j] = prevType
                }
            }

            i = segmentEnd
        }

        return terrainTypes
    }

    // MARK: - Types

    private enum TerrainType: Equatable {
        case climbing, descending, flat

        var color: Color {
            switch self {
            case .climbing: return MilestoneType.montee.color
            case .descending: return MilestoneType.descente.color
            case .flat: return MilestoneType.plat.color
            }
        }
    }

    private struct SegmentInfo {
        let type: MilestoneType
        let description: String
        let progressPercent: Int
    }
}
