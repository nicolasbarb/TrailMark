import Foundation
import Testing
@testable import trailmark

struct ElevationProfileAnalyzerTests {

    // MARK: - Helper Functions

    /// Creates track points with specified elevations and spacing
    private static func makeTrackPoints(
        elevations: [Double],
        distancePerPoint: Double = 100
    ) -> [TrackPoint] {
        elevations.enumerated().map { index, elevation in
            TrackPoint(
                id: nil,
                trailId: 0,
                index: index,
                latitude: 45.0 + Double(index) * 0.001,
                longitude: 6.0,
                elevation: elevation,
                distance: Double(index) * distancePerPoint
            )
        }
    }

    /// Creates a profile: flat -> climb -> flat -> descent -> flat
    private static func makeVariedProfile() -> [TrackPoint] {
        var elevations: [Double] = []

        // Flat section (1km at 1000m)
        for _ in 0..<20 {
            elevations.append(1000)
        }

        // Climb section (150m over 1km)
        for i in 0..<20 {
            elevations.append(1000 + Double(i + 1) * 7.5)
        }

        // Flat section (1km at 1150m)
        for _ in 0..<20 {
            elevations.append(1150)
        }

        // Descent section (100m over 1km)
        for i in 0..<20 {
            elevations.append(1150 - Double(i + 1) * 5)
        }

        // Flat section (1km at 1050m)
        for _ in 0..<20 {
            elevations.append(1050)
        }

        return makeTrackPoints(elevations: elevations, distancePerPoint: 50)
    }

    // MARK: - classify() Tests

    @Test
    func classifyReturnsEmptyForTooFewPoints() {
        let points = Self.makeTrackPoints(elevations: [1000])
        let result = ElevationProfileAnalyzer.classify(trackPoints: points)
        #expect(result.isEmpty)
    }

    @Test
    func classifyReturnsCorrectCountForValidPoints() {
        let points = Self.makeTrackPoints(elevations: [1000, 1000, 1000, 1000, 1000])
        let result = ElevationProfileAnalyzer.classify(trackPoints: points)
        #expect(result.count == points.count)
    }

    @Test
    func classifyDetectsFlatTerrain() {
        // All points at same elevation
        let elevations = Array(repeating: 1000.0, count: 50)
        let points = Self.makeTrackPoints(elevations: elevations, distancePerPoint: 50)
        let result = ElevationProfileAnalyzer.classify(trackPoints: points)

        // Most points should be flat
        let flatCount = result.filter { $0 == .flat }.count
        #expect(flatCount > result.count / 2)
    }

    @Test
    func classifyDetectsClimbingTerrain() {
        // Steady climb: 10m per 100m = 10% slope
        var elevations: [Double] = []
        for i in 0..<50 {
            elevations.append(1000 + Double(i) * 10)
        }
        let points = Self.makeTrackPoints(elevations: elevations, distancePerPoint: 100)
        let result = ElevationProfileAnalyzer.classify(trackPoints: points)

        // Most points should be climbing
        let climbingCount = result.filter { $0 == .climbing }.count
        #expect(climbingCount > result.count / 2)
    }

    @Test
    func classifyDetectsDescendingTerrain() {
        // Steady descent: -10m per 100m = -10% slope
        var elevations: [Double] = []
        for i in 0..<50 {
            elevations.append(1500 - Double(i) * 10)
        }
        let points = Self.makeTrackPoints(elevations: elevations, distancePerPoint: 100)
        let result = ElevationProfileAnalyzer.classify(trackPoints: points)

        // Most points should be descending
        let descendingCount = result.filter { $0 == .descending }.count
        #expect(descendingCount > result.count / 2)
    }

    @Test
    func classifyIgnoresSmallSlopeVariations() {
        // Small variations: 2m per 100m = 2% slope (below 5% threshold)
        var elevations: [Double] = []
        for i in 0..<50 {
            elevations.append(1000 + Double(i) * 2)
        }
        let points = Self.makeTrackPoints(elevations: elevations, distancePerPoint: 100)
        let result = ElevationProfileAnalyzer.classify(trackPoints: points)

        // Should be mostly flat despite slight incline
        let flatCount = result.filter { $0 == .flat }.count
        #expect(flatCount > result.count / 2)
    }

    // MARK: - segments() Tests

    @Test
    func segmentsReturnsEmptyForTooFewPoints() {
        let points = Self.makeTrackPoints(elevations: [1000])
        let result = ElevationProfileAnalyzer.segments(from: points)
        #expect(result.isEmpty)
    }

    @Test
    func segmentsReturnsAtLeastOneSegment() {
        let points = Self.makeVariedProfile()
        let result = ElevationProfileAnalyzer.segments(from: points)
        #expect(!result.isEmpty)
    }

    @Test
    func segmentsCoverAllPoints() {
        let points = Self.makeVariedProfile()
        let segments = ElevationProfileAnalyzer.segments(from: points)

        // First segment should start at index 0
        #expect(segments.first?.startIndex == 0)

        // Last segment should end at last point
        #expect(segments.last?.endIndex == points.count - 1)

        // Segments should be contiguous
        for i in 1..<segments.count {
            #expect(segments[i].startIndex == segments[i - 1].endIndex + 1)
        }
    }

    @Test
    func segmentHasCorrectElevationData() {
        let points = Self.makeVariedProfile()
        let segments = ElevationProfileAnalyzer.segments(from: points)

        for segment in segments {
            let startPoint = points[segment.startIndex]
            let endPoint = points[segment.endIndex]

            #expect(segment.startElevation == startPoint.elevation)
            #expect(segment.endElevation == endPoint.elevation)
            #expect(segment.startDistance == startPoint.distance)
            #expect(segment.endDistance == endPoint.distance)
        }
    }

    @Test
    func segmentElevationGainIsCorrect() {
        let points = Self.makeVariedProfile()
        let segments = ElevationProfileAnalyzer.segments(from: points)

        for segment in segments {
            if segment.type == .climbing {
                #expect(segment.elevationGain > 0)
                #expect(segment.elevationLoss == 0)
            } else if segment.type == .descending {
                #expect(segment.elevationLoss > 0)
                #expect(segment.elevationGain == 0)
            }
        }
    }

    @Test
    func segmentDistanceIsPositive() {
        let points = Self.makeVariedProfile()
        let segments = ElevationProfileAnalyzer.segments(from: points)

        for segment in segments {
            #expect(segment.distance >= 0)
        }
    }

    // MARK: - computeSlope() Tests

    @Test
    func computeSlopeReturnsZeroForFirstPoint() {
        let points = Self.makeTrackPoints(elevations: [1000, 1100, 1200])
        let slope = ElevationProfileAnalyzer.computeSlope(at: 0, trackPoints: points)
        #expect(slope == 0)
    }

    @Test
    func computeSlopeReturnsPositiveForClimb() {
        // Create a steady 10% climb with dense points (10m spacing)
        // so the 100m calculation window has multiple points
        var elevations: [Double] = []
        for i in 0..<50 {
            elevations.append(1000 + Double(i) * 1) // 1m per 10m = 10%
        }
        let points = Self.makeTrackPoints(elevations: elevations, distancePerPoint: 10)

        // Check slope in the middle
        let slope = ElevationProfileAnalyzer.computeSlope(at: 25, trackPoints: points)
        #expect(slope > 0)
    }

    @Test
    func computeSlopeReturnsNegativeForDescent() {
        // Create a steady -10% descent with dense points (10m spacing)
        var elevations: [Double] = []
        for i in 0..<50 {
            elevations.append(1500 - Double(i) * 1) // -1m per 10m = -10%
        }
        let points = Self.makeTrackPoints(elevations: elevations, distancePerPoint: 10)

        // Check slope in the middle
        let slope = ElevationProfileAnalyzer.computeSlope(at: 25, trackPoints: points)
        #expect(slope < 0)
    }

    // MARK: - TerrainType Tests

    @Test
    func terrainTypeHasDistinctColors() {
        // Verify each terrain type has a distinct color
        let climbingColor = TerrainType.climbing.color
        let descendingColor = TerrainType.descending.color
        let flatColor = TerrainType.flat.color

        // Colors should be different from each other
        #expect(climbingColor != descendingColor)
        #expect(climbingColor != flatColor)
        #expect(descendingColor != flatColor)
    }

    @Test
    func terrainTypeHasDistinctUIColors() {
        // Verify each terrain type has a UIColor
        let climbingColor = TerrainType.climbing.uiColor
        let descendingColor = TerrainType.descending.uiColor
        let flatColor = TerrainType.flat.uiColor

        // UIColors should be different from each other
        #expect(climbingColor != descendingColor)
        #expect(climbingColor != flatColor)
        #expect(descendingColor != flatColor)
    }

    // MARK: - Configuration Tests

    @Test
    func configurationValuesAreReasonable() {
        // Slope threshold should be between 1% and 20%
        #expect(ElevationProfileAnalyzer.slopeThreshold >= 0.01)
        #expect(ElevationProfileAnalyzer.slopeThreshold <= 0.20)

        // Window size should be between 100m and 1000m
        #expect(ElevationProfileAnalyzer.slopeWindowSize >= 100)
        #expect(ElevationProfileAnalyzer.slopeWindowSize <= 1000)

        // Min segment length should be between 50m and 500m
        #expect(ElevationProfileAnalyzer.minSegmentLength >= 50)
        #expect(ElevationProfileAnalyzer.minSegmentLength <= 500)
    }
}
