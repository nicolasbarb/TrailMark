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

                let message = AnnouncementBuilder.build(
                    type: .climb,
                    distance: segment.distance,
                    elevation: Double(dPlus),
                    slope: segment.averageSlope
                ) ?? ""

                let milestone = Milestone(
                    trailId: trailId,
                    pointIndex: segment.startIndex,
                    latitude: startPoint.latitude,
                    longitude: startPoint.longitude,
                    elevation: startPoint.elevation,
                    distance: startPoint.distance,
                    type: .climb,
                    message: message
                )
                milestones.append(milestone)

            case .descending:
                // Only create milestone if descent is significant (>= 75m D-)
                let dMinus = Int(segment.elevationLoss)
                guard dMinus >= Int(minimumDescentElevation) else { continue }

                let message = AnnouncementBuilder.build(
                    type: .descent,
                    distance: segment.distance,
                    elevation: Double(dMinus),
                    slope: segment.averageSlope
                ) ?? ""

                let milestone = Milestone(
                    trailId: trailId,
                    pointIndex: segment.startIndex,
                    latitude: startPoint.latitude,
                    longitude: startPoint.longitude,
                    elevation: startPoint.elevation,
                    distance: startPoint.distance,
                    type: .descent,
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

}
