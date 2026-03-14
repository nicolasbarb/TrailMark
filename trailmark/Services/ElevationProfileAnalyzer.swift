import SwiftUI
import UIKit

// MARK: - Terrain Type

enum TerrainType: Equatable {
    case climbing, descending, flat

    var color: Color {
        switch self {
        case .climbing: return MilestoneType.montee.color
        case .descending: return MilestoneType.descente.color
        case .flat: return MilestoneType.plat.color
        }
    }

    var uiColor: UIColor {
        UIColor(color)
    }
}

// MARK: - Trail Profile Analyzer

/// Analyzes trail elevation profile to classify terrain segments
enum ElevationProfileAnalyzer {

    // MARK: - Configuration

    /// Slope threshold for terrain classification (5%)
    static let slopeThreshold: Double = 0.05

    /// Window size for slope calculation in meters (smooths out micro-variations)
    static let slopeWindowSize: Double = 500

    /// Minimum segment length in meters (removes tiny segments)
    static let minSegmentLength: Double = 200

    /// Window size for instantaneous slope calculation in meters
    static let slopeCalcWindow: Double = 100

    // MARK: - Public API

    /// Classifies terrain type for each track point
    /// - Parameter trackPoints: Array of track points to analyze
    /// - Returns: Array of terrain types, one per track point
    static func classify(trackPoints: [TrackPoint]) -> [TerrainType] {
        guard trackPoints.count >= 2 else { return [] }

        var terrainTypes = [TerrainType](repeating: .flat, count: trackPoints.count)
        let halfWindow = slopeWindowSize / 2

        // First pass: compute raw terrain types based on slope
        for i in 0..<trackPoints.count {
            let currentDistance = trackPoints[i].distance

            // Find window boundaries
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

            let distanceDelta = trackPoints[endIdx].distance - trackPoints[startIdx].distance
            guard distanceDelta > 0 else { continue }

            let slope = (trackPoints[endIdx].elevation - trackPoints[startIdx].elevation) / distanceDelta

            if slope > slopeThreshold {
                terrainTypes[i] = .climbing
            } else if slope < -slopeThreshold {
                terrainTypes[i] = .descending
            }
        }

        // Second pass: merge small segments with previous segment
        var i = 0
        while i < trackPoints.count {
            let segmentStart = i
            let segmentType = terrainTypes[i]

            // Find end of this segment
            var segmentEnd = i
            while segmentEnd < trackPoints.count && terrainTypes[segmentEnd] == segmentType {
                segmentEnd += 1
            }

            let segmentLength = trackPoints[min(segmentEnd, trackPoints.count - 1)].distance - trackPoints[segmentStart].distance

            // If segment is too short, merge with previous type
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

    // MARK: - Segment Extraction

    /// A continuous segment of the same terrain type
    struct Segment {
        let startIndex: Int
        let endIndex: Int
        let type: TerrainType
        let startDistance: Double
        let endDistance: Double
        let startElevation: Double
        let endElevation: Double

        var distance: Double { endDistance - startDistance }
        var elevationChange: Double { endElevation - startElevation }
        var elevationGain: Double { max(0, elevationChange) }
        var elevationLoss: Double { abs(min(0, elevationChange)) }
        var averageSlope: Double {
            guard distance > 0 else { return 0 }
            return elevationChange / distance
        }
    }

    /// Extracts terrain segments from track points
    /// - Parameter trackPoints: Array of track points to analyze
    /// - Returns: Array of segments with terrain type and elevation data
    static func segments(from trackPoints: [TrackPoint]) -> [Segment] {
        let terrainTypes = classify(trackPoints: trackPoints)
        guard !terrainTypes.isEmpty else { return [] }

        var segments: [Segment] = []
        var i = 0

        while i < trackPoints.count {
            let segmentStart = i
            let segmentType = terrainTypes[i]

            // Find end of segment
            var segmentEnd = i
            while segmentEnd < trackPoints.count - 1 && terrainTypes[segmentEnd + 1] == segmentType {
                segmentEnd += 1
            }

            let startPoint = trackPoints[segmentStart]
            let endPoint = trackPoints[segmentEnd]

            let segment = Segment(
                startIndex: segmentStart,
                endIndex: segmentEnd,
                type: segmentType,
                startDistance: startPoint.distance,
                endDistance: endPoint.distance,
                startElevation: startPoint.elevation,
                endElevation: endPoint.elevation
            )
            segments.append(segment)

            i = segmentEnd + 1
        }

        return segments
    }

    /// Computes instantaneous slope at a given index using a smaller window
    /// - Parameters:
    ///   - index: The track point index
    ///   - trackPoints: Array of track points
    /// - Returns: Slope as a ratio (e.g., 0.08 for 8%)
    static func computeSlope(at index: Int, trackPoints: [TrackPoint]) -> Double {
        guard index > 0, trackPoints.count > 1 else { return 0 }

        let halfWindow = slopeCalcWindow / 2
        let currentDistance = trackPoints[index].distance

        var startIdx = index
        var endIdx = index

        for j in (0..<index).reversed() {
            if currentDistance - trackPoints[j].distance <= halfWindow {
                startIdx = j
            } else {
                break
            }
        }

        for j in (index + 1)..<trackPoints.count {
            if trackPoints[j].distance - currentDistance <= halfWindow {
                endIdx = j
            } else {
                break
            }
        }

        let distanceDelta = trackPoints[endIdx].distance - trackPoints[startIdx].distance
        guard distanceDelta > 0 else { return 0 }

        return (trackPoints[endIdx].elevation - trackPoints[startIdx].elevation) / distanceDelta
    }

    // MARK: - Lookahead Stats

    /// Stats for the remaining terrain zone from a given point forward
    struct LookaheadStats: Equatable, Sendable {
        let terrainType: TerrainType
        let distance: Double        // meters
        let elevationGain: Double   // meters (>= 0)
        let elevationLoss: Double   // meters (>= 0)
        let averageSlope: Double    // ratio (e.g., 0.12 for 12%)
    }

    /// Computes remaining terrain zone stats from a given track point index
    /// - Parameters:
    ///   - pointIndex: Starting track point index
    ///   - trackPoints: Full array of track points
    ///   - terrainTypes: Terrain classification per point (from `classify()`)
    /// - Returns: Stats for the remaining zone, or nil if remaining distance < minSegmentLength
    static func computeLookaheadStats(
        from pointIndex: Int,
        trackPoints: [TrackPoint],
        terrainTypes: [TerrainType]
    ) -> LookaheadStats? {
        guard pointIndex >= 0,
              pointIndex < trackPoints.count,
              terrainTypes.count == trackPoints.count else { return nil }

        let startType = terrainTypes[pointIndex]
        let startPoint = trackPoints[pointIndex]

        // Walk forward while terrain type matches
        var endIndex = pointIndex
        while endIndex + 1 < trackPoints.count && terrainTypes[endIndex + 1] == startType {
            endIndex += 1
        }

        let endPoint = trackPoints[endIndex]
        let distance = endPoint.distance - startPoint.distance

        // Skip if remaining distance is below minimum
        guard distance >= minSegmentLength else { return nil }

        // Compute actual elevation gain/loss between start and end
        var gain: Double = 0
        var loss: Double = 0
        for i in pointIndex..<endIndex {
            let delta = trackPoints[i + 1].elevation - trackPoints[i].elevation
            if delta > 0 { gain += delta }
            else { loss += abs(delta) }
        }

        let elevationChange = endPoint.elevation - startPoint.elevation
        let slope = distance > 0 ? elevationChange / distance : 0

        return LookaheadStats(
            terrainType: startType,
            distance: distance,
            elevationGain: gain,
            elevationLoss: loss,
            averageSlope: slope
        )
    }
}
