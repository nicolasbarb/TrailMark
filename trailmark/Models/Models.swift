import Foundation
import StructuredQueries

// MARK: - Trail

@Table("trail")
struct Trail: Hashable, Identifiable, Sendable {
    let id: Int64?
    var name: String
    var createdAt: Double // Unix timestamp
    var distance: Double // meters
    var dPlus: Int // meters
    var color: String // TrailColor raw value

    nonisolated init(
        id: Int64? = nil,
        name: String,
        createdAt: Date = Date(),
        distance: Double,
        dPlus: Int,
        trailColor: TrailColor = .default
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt.timeIntervalSince1970
        self.distance = distance
        self.dPlus = dPlus
        self.color = trailColor.rawValue
    }

    // Init with raw timestamp (for database reconstruction)
    nonisolated init(
        id: Int64?,
        name: String,
        createdAtTimestamp: Double,
        distance: Double,
        dPlus: Int,
        color: String
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAtTimestamp
        self.distance = distance
        self.dPlus = dPlus
        self.color = color
    }

    nonisolated var createdAtDate: Date {
        Date(timeIntervalSince1970: createdAt)
    }

    /// SwiftUI Color from stored color value
    nonisolated var trailColor: TrailColor {
        TrailColor(rawValue: color) ?? .default
    }
}

// MARK: - TrackPoint

@Table("trackPoint")
struct TrackPoint: Hashable, Identifiable, Sendable {
    let id: Int64?
    var trailId: Int64
    var index: Int
    var latitude: Double
    var longitude: Double
    var elevation: Double // meters
    var distance: Double // cumulative distance from start, meters

    nonisolated init(
        id: Int64? = nil,
        trailId: Int64 = 0,
        index: Int,
        latitude: Double,
        longitude: Double,
        elevation: Double,
        distance: Double
    ) {
        self.id = id
        self.trailId = trailId
        self.index = index
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.distance = distance
    }
}

// MARK: - MilestoneType

enum MilestoneType: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case montee
    case descente
    case plat
    case ravito
    case danger
    case info
}

// MARK: - Milestone

@Table("milestone")
struct Milestone: Hashable, Identifiable, Sendable {
    let id: Int64?
    var trailId: Int64
    var pointIndex: Int
    var latitude: Double
    var longitude: Double
    var elevation: Double
    var distance: Double // cumulative distance
    var type: String // MilestoneType raw value
    var message: String
    var name: String?

    nonisolated init(
        id: Int64? = nil,
        trailId: Int64 = 0,
        pointIndex: Int,
        latitude: Double,
        longitude: Double,
        elevation: Double,
        distance: Double,
        type: MilestoneType,
        message: String,
        name: String? = nil
    ) {
        self.id = id
        self.trailId = trailId
        self.pointIndex = pointIndex
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.distance = distance
        self.type = type.rawValue
        self.message = message
        self.name = name
    }

    nonisolated var milestoneType: MilestoneType {
        MilestoneType(rawValue: type) ?? .info
    }
}

// MARK: - TrailDetail (Aggregated view)

struct TrailDetail: Equatable, Sendable {
    var trail: Trail
    var trackPoints: [TrackPoint]
    var milestones: [Milestone]

    nonisolated init(trail: Trail, trackPoints: [TrackPoint], milestones: [Milestone]) {
        self.trail = trail
        self.trackPoints = trackPoints
        self.milestones = milestones
    }

    nonisolated var distKm: String {
        String(format: "%.1f", trail.distance / 1000)
    }

    nonisolated var milestoneCount: Int {
        milestones.count
    }
}
