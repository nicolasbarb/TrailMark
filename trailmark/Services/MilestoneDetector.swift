import Foundation

/// Algorithme de détection automatique des jalons basé sur le profil altimétrique
enum MilestoneDetector {

    // MARK: - Configuration

    /// Dénivelé minimum pour considérer une montée significative (75m)
    static let minimumClimbElevation: Double = 75

    /// Dénivelé minimum pour considérer une descente significative (75m)
    static let minimumDescentElevation: Double = 75

    /// Distance minimale entre deux jalons (1km)
    static let minimumDistanceBetweenMilestones: Double = 1000

    /// Fenêtre de lissage pour réduire le bruit GPS (200m)
    static let smoothingWindow: Double = 200

    // MARK: - Types

    private enum Trend {
        case climbing
        case descending
        case flat
    }

    private struct Segment {
        let startIndex: Int
        let endIndex: Int
        let trend: Trend
        let startDistance: Double
        let endDistance: Double
        let startElevation: Double
        let endElevation: Double

        var distance: Double { endDistance - startDistance }
        var elevationChange: Double { abs(endElevation - startElevation) }
        var averageSlope: Double {
            guard distance > 0 else { return 0 }
            return (endElevation - startElevation) / distance
        }
    }

    // MARK: - Public API

    /// Détecte les jalons automatiquement à partir des points de la trace
    static func detect(from trackPoints: [TrackPoint], trailId: Int64 = 0) -> [Milestone] {
        guard trackPoints.count >= 10 else { return [] }

        // 1. Lisser le profil
        let smoothedElevations = smooth(trackPoints: trackPoints)

        // 2. Détecter les segments significatifs (montées/descentes avec D+ ou D- > seuil)
        let segments = detectSignificantSegments(trackPoints: trackPoints, smoothedElevations: smoothedElevations)

        // 3. Générer les jalons
        var milestones = generateMilestones(from: segments, trackPoints: trackPoints, smoothedElevations: smoothedElevations, trailId: trailId)

        // 4. Filtrer les jalons trop proches
        milestones = filterByMinimumDistance(milestones)

        return milestones
    }

    // MARK: - Smoothing

    private static func smooth(trackPoints: [TrackPoint]) -> [Double] {
        var smoothed = [Double]()
        smoothed.reserveCapacity(trackPoints.count)

        for (index, point) in trackPoints.enumerated() {
            let targetDistance = point.distance
            var sum = 0.0
            var count = 0

            for otherPoint in trackPoints {
                let distanceFromTarget = abs(otherPoint.distance - targetDistance)
                if distanceFromTarget <= smoothingWindow / 2 {
                    sum += otherPoint.elevation
                    count += 1
                }
            }

            smoothed.append(count > 0 ? sum / Double(count) : point.elevation)
        }

        return smoothed
    }

    // MARK: - Segment Detection

    /// Détecte les segments significatifs basés sur le dénivelé cumulé
    private static func detectSignificantSegments(trackPoints: [TrackPoint], smoothedElevations: [Double]) -> [Segment] {
        var segments: [Segment] = []

        var segmentStartIndex = 0
        var currentTrend: Trend = .flat
        var cumulativeChange: Double = 0
        var lastElevation = smoothedElevations[0]

        for i in 1..<trackPoints.count {
            let currentElevation = smoothedElevations[i]
            let delta = currentElevation - lastElevation

            // Déterminer la tendance de ce delta
            let deltaTrend: Trend = delta > 5 ? .climbing : (delta < -5 ? .descending : .flat)

            // Si on change de tendance ou si on accumule assez de dénivelé
            let trendChanged = deltaTrend != .flat && deltaTrend != currentTrend && currentTrend != .flat

            if trendChanged {
                // Vérifier si le segment précédent était significatif
                let threshold = currentTrend == .climbing ? minimumClimbElevation : minimumDescentElevation
                if abs(cumulativeChange) >= threshold {
                    let segment = Segment(
                        startIndex: segmentStartIndex,
                        endIndex: i - 1,
                        trend: currentTrend,
                        startDistance: trackPoints[segmentStartIndex].distance,
                        endDistance: trackPoints[i - 1].distance,
                        startElevation: smoothedElevations[segmentStartIndex],
                        endElevation: smoothedElevations[i - 1]
                    )
                    segments.append(segment)
                }

                // Commencer un nouveau segment
                segmentStartIndex = i - 1
                currentTrend = deltaTrend
                cumulativeChange = delta
            } else if deltaTrend != .flat {
                // Continuer à accumuler dans la même direction
                if currentTrend == .flat {
                    currentTrend = deltaTrend
                    segmentStartIndex = i - 1
                }
                cumulativeChange += delta
            }

            lastElevation = currentElevation
        }

        // Ajouter le dernier segment s'il est significatif
        let threshold = currentTrend == .climbing ? minimumClimbElevation : minimumDescentElevation
        if abs(cumulativeChange) >= threshold {
            let segment = Segment(
                startIndex: segmentStartIndex,
                endIndex: trackPoints.count - 1,
                trend: currentTrend,
                startDistance: trackPoints[segmentStartIndex].distance,
                endDistance: trackPoints[trackPoints.count - 1].distance,
                startElevation: smoothedElevations[segmentStartIndex],
                endElevation: smoothedElevations[trackPoints.count - 1]
            )
            segments.append(segment)
        }

        return segments
    }

    // MARK: - Milestone Generation

    private static func generateMilestones(from segments: [Segment], trackPoints: [TrackPoint], smoothedElevations: [Double], trailId: Int64) -> [Milestone] {
        var milestones: [Milestone] = []

        for segment in segments {
            guard segment.startIndex < trackPoints.count else { continue }
            let startPoint = trackPoints[segment.startIndex]

            switch segment.trend {
            case .climbing:
                let dPlus = Int(max(0, segment.endElevation - segment.startElevation))
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
                let dMinus = Int(abs(segment.endElevation - segment.startElevation))
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
        if distKm >= 1 {
            return "Montée de \(dPlus) mètres sur \(String(format: "%.1f", distKm)) kilomètres — \(slopePercent)% moyen"
        } else {
            let distM = Int(distKm * 1000)
            return "Montée de \(dPlus) mètres sur \(distM) mètres — \(slopePercent)% moyen"
        }
    }

    private static func formatDescentMessage(dMinus: Int, distKm: Double) -> String {
        if distKm >= 1 {
            return "Descente de \(dMinus) mètres sur \(String(format: "%.1f", distKm)) kilomètres"
        } else {
            let distM = Int(distKm * 1000)
            return "Descente de \(dMinus) mètres sur \(distM) mètres"
        }
    }
}
