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
                let message = formatDescentMessage(dMinus: dMinus, distKm: distKm)

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

    // MARK: - Climb Categories

    enum ClimbCategory: String {
        case hc = "Hors Catégorie"
        case cat1 = "Catégorie 1"
        case cat2 = "Catégorie 2"
        case cat3 = "Catégorie 3"
        case cat4 = "Catégorie 4"

        var shortName: String {
            switch self {
            case .hc: return "HC"
            case .cat1: return "Cat 1"
            case .cat2: return "Cat 2"
            case .cat3: return "Cat 3"
            case .cat4: return "Cat 4"
            }
        }

        /// Categorizes a climb based on elevation gain
        static func from(elevationGain: Int) -> ClimbCategory {
            switch elevationGain {
            case 1000...: return .hc
            case 600..<1000: return .cat1
            case 300..<600: return .cat2
            case 150..<300: return .cat3
            default: return .cat4
            }
        }
    }

    // MARK: - Message Formatting

    private static func formatClimbMessage(dPlus: Int, distKm: Double, slopePercent: Int) -> String {
        let category = ClimbCategory.from(elevationGain: dPlus)

        if distKm >= 1 {
            return "Montée \(category.shortName) — \(dPlus) mètres sur \(String(format: "%.1f", distKm)) kilomètres, \(slopePercent)% moyen"
        } else {
            let distM = Int(distKm * 1000)
            return "Montée \(category.shortName) — \(dPlus) mètres sur \(distM) mètres, \(slopePercent)% moyen"
        }
    }

    private static func formatDescentMessage(dMinus: Int, distKm: Double) -> String {
        let category = ClimbCategory.from(elevationGain: dMinus)

        if distKm >= 1 {
            return "Descente \(category.shortName) — \(dMinus) mètres sur \(String(format: "%.1f", distKm)) kilomètres"
        } else {
            let distM = Int(distKm * 1000)
            return "Descente \(category.shortName) — \(dMinus) mètres sur \(distM) mètres"
        }
    }
}
