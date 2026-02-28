import Foundation
import Testing
@testable import trailmark

struct MilestoneDetectorTests {

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

    /// Creates a simple climb profile: flat -> climb -> flat
    private static func makeClimbProfile(
        startElevation: Double = 1000,
        climbAmount: Double,
        climbDistance: Double,
        flatBefore: Double = 500,
        flatAfter: Double = 500
    ) -> [TrackPoint] {
        var points: [TrackPoint] = []
        let spacing = 50.0

        // Flat before
        let flatBeforeCount = Int(flatBefore / spacing)
        for i in 0..<flatBeforeCount {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: startElevation,
                distance: Double(points.count) * spacing
            ))
        }

        // Climb
        let climbCount = Int(climbDistance / spacing)
        let elevationPerStep = climbAmount / Double(climbCount)
        for i in 0..<climbCount {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: startElevation + elevationPerStep * Double(i + 1),
                distance: Double(points.count) * spacing
            ))
        }

        // Flat after
        let flatAfterCount = Int(flatAfter / spacing)
        let endElevation = startElevation + climbAmount
        for i in 0..<flatAfterCount {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: endElevation,
                distance: Double(points.count) * spacing
            ))
        }

        return points
    }

    // MARK: - Basic Tests

    @Test
    func detectReturnsEmptyForTooFewPoints() {
        let points = Self.makeTrackPoints(elevations: [1000, 1000, 1000])
        let milestones = MilestoneDetector.detect(from: points)
        #expect(milestones.isEmpty)
    }

    @Test
    func detectReturnsEmptyForFlatProfile() {
        // 50 points of flat terrain
        let elevations = Array(repeating: 1000.0, count: 50)
        let points = Self.makeTrackPoints(elevations: elevations, distancePerPoint: 100)
        let milestones = MilestoneDetector.detect(from: points)
        #expect(milestones.isEmpty)
    }

    // MARK: - Climb Detection

    @Test
    func detectsSignificantClimb() {
        // Climb of 100m over 1km (significant, > 75m threshold)
        let points = Self.makeClimbProfile(
            climbAmount: 100,
            climbDistance: 1000,
            flatBefore: 1000,
            flatAfter: 1000
        )

        let milestones = MilestoneDetector.detect(from: points)

        #expect(milestones.count >= 1)
        if let first = milestones.first {
            #expect(first.milestoneType == .montee)
        }
    }

    @Test
    func ignoresSmallClimb() {
        // Climb of only 50m (below 75m threshold)
        let points = Self.makeClimbProfile(
            climbAmount: 50,
            climbDistance: 500,
            flatBefore: 1000,
            flatAfter: 1000
        )

        let milestones = MilestoneDetector.detect(from: points)

        // Should not detect a milestone for such a small climb
        let climbMilestones = milestones.filter { $0.milestoneType == .montee }
        #expect(climbMilestones.isEmpty)
    }

    // MARK: - Descent Detection

    @Test
    func detectsSignificantDescent() {
        // Create descent of 100m over 1km
        var points: [TrackPoint] = []
        let spacing = 50.0

        // Flat before
        for i in 0..<20 {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: 1100,
                distance: Double(points.count) * spacing
            ))
        }

        // Descent
        for i in 0..<20 {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: 1100 - Double(i + 1) * 5,
                distance: Double(points.count) * spacing
            ))
        }

        // Flat after
        for i in 0..<20 {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: 1000,
                distance: Double(points.count) * spacing
            ))
        }

        let milestones = MilestoneDetector.detect(from: points)

        let descentMilestones = milestones.filter { $0.milestoneType == .descente }
        #expect(descentMilestones.count >= 1)
    }

    // MARK: - Minimum Distance Filtering

    @Test
    func filtersMilestonesTooClose() {
        // Create two climbs that are close together
        var points: [TrackPoint] = []
        let spacing = 50.0

        // First climb: 100m
        for i in 0..<10 {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: 1000 + Double(i) * 10,
                distance: Double(points.count) * spacing
            ))
        }

        // Small gap (less than 1km minimum distance)
        for i in 0..<5 {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: 1100,
                distance: Double(points.count) * spacing
            ))
        }

        // Second climb: 100m
        for i in 0..<10 {
            points.append(TrackPoint(
                id: nil,
                trailId: 0,
                index: points.count,
                latitude: 45.0 + Double(points.count) * 0.0001,
                longitude: 6.0,
                elevation: 1100 + Double(i) * 10,
                distance: Double(points.count) * spacing
            ))
        }

        let milestones = MilestoneDetector.detect(from: points)

        // With minimum distance of 1km, the second climb should be filtered out
        // Total distance is only ~1250m, so only one milestone should remain
        #expect(milestones.count <= 1)
    }

    // MARK: - Trail ID

    @Test
    func assignsCorrectTrailId() {
        let points = Self.makeClimbProfile(
            climbAmount: 100,
            climbDistance: 1000,
            flatBefore: 1000,
            flatAfter: 1000
        )

        let trailId: Int64 = 42
        let milestones = MilestoneDetector.detect(from: points, trailId: trailId)

        for milestone in milestones {
            #expect(milestone.trailId == trailId)
        }
    }

    // MARK: - Message Formatting

    @Test
    func climbMessageContainsElevationGain() {
        let points = Self.makeClimbProfile(
            climbAmount: 150,
            climbDistance: 2000,
            flatBefore: 1500,
            flatAfter: 500
        )

        let milestones = MilestoneDetector.detect(from: points)

        if let climb = milestones.first(where: { $0.milestoneType == .montee }) {
            #expect(climb.message.contains("Montée"))
            #expect(climb.message.contains("mètres"))
        }
    }

    // MARK: - Climb Category

    @Test
    func climbCategoryClassification() {
        #expect(MilestoneDetector.ClimbCategory.from(elevationGain: 50) == .cat4)
        #expect(MilestoneDetector.ClimbCategory.from(elevationGain: 150) == .cat3)
        #expect(MilestoneDetector.ClimbCategory.from(elevationGain: 350) == .cat2)
        #expect(MilestoneDetector.ClimbCategory.from(elevationGain: 700) == .cat1)
        #expect(MilestoneDetector.ClimbCategory.from(elevationGain: 1200) == .hc)
    }

    @Test
    func climbCategoryShortNames() {
        #expect(MilestoneDetector.ClimbCategory.cat4.shortName == "Cat 4")
        #expect(MilestoneDetector.ClimbCategory.cat3.shortName == "Cat 3")
        #expect(MilestoneDetector.ClimbCategory.cat2.shortName == "Cat 2")
        #expect(MilestoneDetector.ClimbCategory.cat1.shortName == "Cat 1")
        #expect(MilestoneDetector.ClimbCategory.hc.shortName == "HC")
    }

    // MARK: - Milestone Properties

    @Test
    func milestonesAreSortedByDistance() {
        // Create a complex profile with multiple climbs/descents
        var elevations: [Double] = []

        // First climb at ~0m
        for i in 0..<20 {
            elevations.append(1000 + Double(i) * 5)
        }
        // Flat
        for _ in 0..<30 {
            elevations.append(1100)
        }
        // Descent at ~2500m
        for i in 0..<20 {
            elevations.append(1100 - Double(i) * 5)
        }
        // Flat
        for _ in 0..<30 {
            elevations.append(1000)
        }

        let points = Self.makeTrackPoints(elevations: elevations, distancePerPoint: 50)
        let milestones = MilestoneDetector.detect(from: points)

        // Verify sorted order
        for i in 1..<milestones.count {
            #expect(milestones[i].distance >= milestones[i - 1].distance)
        }
    }

    @Test
    func milestonePointIndexIsValid() {
        let points = Self.makeClimbProfile(
            climbAmount: 100,
            climbDistance: 1000,
            flatBefore: 1000,
            flatAfter: 1000
        )

        let milestones = MilestoneDetector.detect(from: points)

        for milestone in milestones {
            #expect(milestone.pointIndex >= 0)
            #expect(milestone.pointIndex < points.count)
        }
    }
}
