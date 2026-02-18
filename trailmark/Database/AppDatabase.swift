import Foundation
import GRDB
import SQLiteData
import Dependencies
import StructuredQueries

// MARK: - Database Setup

/// Creates and configures the application database with migrations
func appDatabase() throws -> any DatabaseWriter {
    let fileManager = FileManager.default
    let appSupportURL = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let directoryURL = appSupportURL.appendingPathComponent("TrailMark", isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    let databaseURL = directoryURL.appendingPathComponent("db.sqlite")

    var configuration = Configuration()
    #if DEBUG
    configuration.prepareDatabase { db in
        db.trace { print("SQL: \($0)") }
    }
    #endif

    let dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
    try migrator.migrate(dbQueue)
    return dbQueue
}

/// Creates an in-memory database for testing
func testDatabase() throws -> any DatabaseWriter {
    let dbQueue = try DatabaseQueue(configuration: Configuration())
    try migrator.migrate(dbQueue)
    return dbQueue
}

// MARK: - Migrations

private var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()

    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("v1") { db in
        // Trail table
        try db.execute(sql: """
            CREATE TABLE trail (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                createdAt REAL NOT NULL,
                distance REAL NOT NULL,
                dPlus INTEGER NOT NULL,
                color TEXT NOT NULL DEFAULT 'f97316'
            )
            """)

        // TrackPoint table
        try db.execute(sql: """
            CREATE TABLE trackPoint (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                trailId INTEGER NOT NULL REFERENCES trail(id) ON DELETE CASCADE,
                "index" INTEGER NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                elevation REAL NOT NULL,
                distance REAL NOT NULL
            )
            """)

        // Index for efficient queries
        try db.execute(sql: """
            CREATE INDEX trackPoint_trailId_index ON trackPoint(trailId, "index")
            """)

        // Milestone table
        try db.execute(sql: """
            CREATE TABLE milestone (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                trailId INTEGER NOT NULL REFERENCES trail(id) ON DELETE CASCADE,
                pointIndex INTEGER NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                elevation REAL NOT NULL,
                distance REAL NOT NULL,
                type TEXT NOT NULL,
                message TEXT NOT NULL,
                name TEXT
            )
            """)

        // Index for milestone queries
        try db.execute(sql: """
            CREATE INDEX milestone_trailId ON milestone(trailId)
            """)
    }

    return migrator
}

// MARK: - DatabaseClient

struct DatabaseClient: Sendable {
    var fetchAllTrails: @Sendable () async throws -> [TrailListItem]
    var fetchTrailDetail: @Sendable (Int64) async throws -> TrailDetail?
    var insertTrail: @Sendable (Trail, [TrackPoint]) async throws -> Trail
    var deleteTrail: @Sendable (Int64) async throws -> Void
    var saveMilestones: @Sendable (Int64, [Milestone]) async throws -> Void
    var updateTrailName: @Sendable (Int64, String) async throws -> Void
}

// MARK: - DependencyKey

extension DatabaseClient: DependencyKey {
    static var liveValue: DatabaseClient {
        // Use the default database from dependencies
        @Dependency(\.defaultDatabase) var database

        return DatabaseClient(
            fetchAllTrails: {
                try await database.read { db in
                    let trails = try Trail
                        .order { col in col.createdAt.desc() }
                        .fetchAll(db)

                    return try trails.map { trail in
                        let count = try Milestone
                            .where { col in col.trailId == trail.id }
                            .fetchCount(db)
                        return TrailListItem(trail: trail, milestoneCount: count)
                    }
                }
            },
            fetchTrailDetail: { trailId in
                try await database.read { db in
                    let trailQuery = Trail.where { col in col.id == trailId }
                    guard let trail = try trailQuery.fetchOne(db) else {
                        return nil
                    }
                    let trackPoints = try TrackPoint
                        .where { col in col.trailId == trailId }
                        .order { col in col.index.asc() }
                        .fetchAll(db)
                    let milestones = try Milestone
                        .where { col in col.trailId == trailId }
                        .order { col in col.distance.asc() }
                        .fetchAll(db)
                    return TrailDetail(trail: trail, trackPoints: trackPoints, milestones: milestones)
                }
            },
            insertTrail: { trail, trackPoints in
                try await database.write { db in
                    // Insert trail and get the generated ID
                    try Trail.insert {
                        Trail.Draft(
                            name: trail.name,
                            createdAt: trail.createdAt,
                            distance: trail.distance,
                            dPlus: trail.dPlus,
                            color: trail.color
                        )
                    }
                    .execute(db)

                    let newTrailId = db.lastInsertedRowID

                    // Insert all track points
                    for point in trackPoints {
                        try TrackPoint.insert {
                            TrackPoint.Draft(
                                trailId: newTrailId,
                                index: point.index,
                                latitude: point.latitude,
                                longitude: point.longitude,
                                elevation: point.elevation,
                                distance: point.distance
                            )
                        }
                        .execute(db)
                    }

                    // Return the inserted trail with its new ID
                    return Trail(
                        id: newTrailId,
                        name: trail.name,
                        createdAtTimestamp: trail.createdAt,
                        distance: trail.distance,
                        dPlus: trail.dPlus,
                        color: trail.color
                    )
                }
            },
            deleteTrail: { trailId in
                try await database.write { db in
                    try Trail.delete()
                        .where { col in col.id == trailId }
                        .execute(db)
                }
            },
            saveMilestones: { trailId, milestones in
                try await database.write { db in
                    // Delete all existing milestones for this trail
                    try Milestone.delete()
                        .where { col in col.trailId == trailId }
                        .execute(db)

                    // Insert new milestones
                    for milestone in milestones {
                        try Milestone.insert {
                            Milestone.Draft(
                                trailId: trailId,
                                pointIndex: milestone.pointIndex,
                                latitude: milestone.latitude,
                                longitude: milestone.longitude,
                                elevation: milestone.elevation,
                                distance: milestone.distance,
                                type: milestone.type,
                                message: milestone.message,
                                name: milestone.name
                            )
                        }
                        .execute(db)
                    }
                }
            },
            updateTrailName: { trailId, newName in
                try await database.write { db in
                    try Trail.update { $0.name = newName }
                        .where { $0.id == trailId }
                        .execute(db)
                }
            }
        )
    }

    static var testValue: DatabaseClient {
        DatabaseClient(
            fetchAllTrails: { [TrailListItem]() },
            fetchTrailDetail: { _ in nil },
            insertTrail: { trail, _ in trail },
            deleteTrail: { _ in },
            saveMilestones: { _, _ in },
            updateTrailName: { _, _ in }
        )
    }

    static var previewValue: DatabaseClient {
        // For previews, use a real in-memory database
        let database: any DatabaseWriter = {
            do {
                return try testDatabase()
            } catch {
                fatalError("Preview database setup failed: \(error)")
            }
        }()

        return DatabaseClient(
            fetchAllTrails: {
                try await database.read { db in
                    let trails = try Trail
                        .order { col in col.createdAt.desc() }
                        .fetchAll(db)

                    return try trails.map { trail in
                        let count = try Milestone
                            .where { col in col.trailId == trail.id }
                            .fetchCount(db)
                        return TrailListItem(trail: trail, milestoneCount: count)
                    }
                }
            },
            fetchTrailDetail: { trailId in
                try await database.read { db in
                    let trailQuery = Trail.where { col in col.id == trailId }
                    guard let trail = try trailQuery.fetchOne(db) else {
                        return nil
                    }
                    let trackPoints = try TrackPoint
                        .where { col in col.trailId == trailId }
                        .order { col in col.index.asc() }
                        .fetchAll(db)
                    let milestones = try Milestone
                        .where { col in col.trailId == trailId }
                        .order { col in col.distance.asc() }
                        .fetchAll(db)
                    return TrailDetail(trail: trail, trackPoints: trackPoints, milestones: milestones)
                }
            },
            insertTrail: { trail, trackPoints in
                try await database.write { db in
                    try Trail.insert {
                        Trail.Draft(
                            name: trail.name,
                            createdAt: trail.createdAt,
                            distance: trail.distance,
                            dPlus: trail.dPlus,
                            color: trail.color
                        )
                    }
                    .execute(db)

                    let newTrailId = db.lastInsertedRowID

                    for point in trackPoints {
                        try TrackPoint.insert {
                            TrackPoint.Draft(
                                trailId: newTrailId,
                                index: point.index,
                                latitude: point.latitude,
                                longitude: point.longitude,
                                elevation: point.elevation,
                                distance: point.distance
                            )
                        }
                        .execute(db)
                    }

                    return Trail(
                        id: newTrailId,
                        name: trail.name,
                        createdAtTimestamp: trail.createdAt,
                        distance: trail.distance,
                        dPlus: trail.dPlus,
                        color: trail.color
                    )
                }
            },
            deleteTrail: { trailId in
                try await database.write { db in
                    try Trail.delete()
                        .where { col in col.id == trailId }
                        .execute(db)
                }
            },
            saveMilestones: { trailId, milestones in
                try await database.write { db in
                    try Milestone.delete()
                        .where { col in col.trailId == trailId }
                        .execute(db)

                    for milestone in milestones {
                        try Milestone.insert {
                            Milestone.Draft(
                                trailId: trailId,
                                pointIndex: milestone.pointIndex,
                                latitude: milestone.latitude,
                                longitude: milestone.longitude,
                                elevation: milestone.elevation,
                                distance: milestone.distance,
                                type: milestone.type,
                                message: milestone.message,
                                name: milestone.name
                            )
                        }
                        .execute(db)
                    }
                }
            },
            updateTrailName: { trailId, newName in
                try await database.write { db in
                    try Trail.update { $0.name = newName }
                        .where { $0.id == trailId }
                        .execute(db)
                }
            }
        )
    }
}

extension DependencyValues {
    var database: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}

// MARK: - DatabaseError

struct DatabaseError: Error {
    let message: String
}

// MARK: - Bootstrap Database Extension

extension DependencyValues {
    /// Bootstraps the database for the live app
    mutating func bootstrapDatabase() throws {
        self.defaultDatabase = try appDatabase()
    }
}
