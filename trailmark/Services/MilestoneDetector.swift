import Foundation

/// Automatic milestone detection based on elevation profile analysis
enum MilestoneDetector {

    // MARK: - Configuration

    /// Minimum elevation gain to consider a climb significant (75m)
    static let minimumClimbElevation: Double = 75

    /// Minimum elevation loss to consider a descent significant (75m)
    static let minimumDescentElevation: Double = 75

    /// Minimum distance between two milestones (1km)
    static let minimumDistanceBetweenMilestones: Double = 1000

    // MARK: - Public API

    /// Detects milestones automatically from track points
    /// Uses ElevationProfileAnalyzer for terrain segmentation
    static func detect(from trackPoints: [TrackPoint], trailId: Int64 = 0) -> [Milestone] {
        guard trackPoints.count >= 10 else { return [] }

        // 1. Get terrain segments from shared analyzer
        let segments = ElevationProfileAnalyzer.segments(from: trackPoints)

        // 2. Filter significant segments and generate milestones
        var milestones = generateMilestones(
            from: segments,
            trackPoints: trackPoints,
            trailId: trailId
        )

        // 3. Filter milestones too close together
        milestones = filterByMinimumDistance(milestones)

        return milestones
    }

    // MARK: - Milestone Generation

    private static func generateMilestones(
        from segments: [ElevationProfileAnalyzer.Segment],
        trackPoints: [TrackPoint],
        trailId: Int64
    ) -> [Milestone] {
        var milestones: [Milestone] = []

        for segment in segments {
            guard segment.startIndex < trackPoints.count else { continue }
            let startPoint = trackPoints[segment.startIndex]

            switch segment.type {
            case .climbing:
                // Only create milestone if climb is significant (>= 75m D+)
                let dPlus = Int(segment.elevationGain)
                guard dPlus >= Int(minimumClimbElevation) else { continue }

                let distKm = segment.distance / 1000
                let slopePercent = Int(abs(segment.averageSlope * 100))
                let message = formatClimbMessage(dPlus: dPlus, distKm: distKm, slopePercent: slopePercent)

                let milestone = Milestone(
                    trailId: trailId,
                    pointIndex: segment.startIndex,
                    latitude: startPoint.latitude,
                    longitude: startPoint.longitude,
                    elevation: startPoint.elevation,
                    distance: startPoint.distance,
                    type: .montee,
                    message: message
                )
                milestones.append(milestone)

            case .descending:
                // Only create milestone if descent is significant (>= 75m D-)
                let dMinus = Int(segment.elevationLoss)
                guard dMinus >= Int(minimumDescentElevation) else { continue }

                let distKm = segment.distance / 1000
                let slopePercent = Int(abs(segment.averageSlope * 100))
                let message = formatDescentMessage(dMinus: dMinus, distKm: distKm, slopePercent: slopePercent)

                let milestone = Milestone(
                    trailId: trailId,
                    pointIndex: segment.startIndex,
                    latitude: startPoint.latitude,
                    longitude: startPoint.longitude,
                    elevation: startPoint.elevation,
                    distance: startPoint.distance,
                    type: .descente,
                    message: message
                )
                milestones.append(milestone)

            case .flat:
                // No milestone for flat sections
                break
            }
        }

        return milestones.sorted { $0.distance < $1.distance }
    }

    // MARK: - Distance Filtering

    private static func filterByMinimumDistance(_ milestones: [Milestone]) -> [Milestone] {
        guard !milestones.isEmpty else { return [] }

        var filtered: [Milestone] = []
        var lastDistance: Double = -minimumDistanceBetweenMilestones

        for milestone in milestones {
            if milestone.distance - lastDistance >= minimumDistanceBetweenMilestones {
                filtered.append(milestone)
                lastDistance = milestone.distance
            }
        }

        return filtered
    }

    // MARK: - Message Formatting

    private static func formatClimbMessage(dPlus: Int, distKm: Double, slopePercent: Int) -> String {
        let dist = distKm >= 1
            ? "\(String(format: "%.1f", distKm)) km"
            : "\(Int(distKm * 1000)) m"

        return "Montée de \(dPlus) m sur \(dist). Pente moyenne \(slopePercent)%."
    }

    private static func formatDescentMessage(dMinus: Int, distKm: Double, slopePercent: Int) -> String {
        let dist = distKm >= 1
            ? "\(String(format: "%.1f", distKm)) km"
            : "\(Int(distKm * 1000)) m"

        return "Descente de \(dMinus) m sur \(dist). Pente moyenne \(slopePercent)%."
    }
}
