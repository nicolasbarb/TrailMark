import Foundation
import Testing
@testable import trailmark

struct AnnouncementBuilderTests {

    // MARK: - Montée

    @Test
    func montee_generatesCorrectMessage() throws {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .climbing,
            distance: 1800,
            elevationGain: 215,
            elevationLoss: 0,
            averageSlope: 0.12
        )

        let result = AnnouncementBuilder.build(
            type: .montee,
            name: nil,
            lookaheadStats: stats
        )

        let message = try #require(result)
        #expect(message.contains("Montée"))
        #expect(message.contains("1 virgule 8 kilomètres"))
        #expect(message.contains("12 pourcent"))
        #expect(message.contains("215 mètres de dénivelé positif"))
    }

    @Test
    func montee_withName_includesName() throws {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .climbing,
            distance: 2000,
            elevationGain: 300,
            elevationLoss: 0,
            averageSlope: 0.15
        )

        let result = AnnouncementBuilder.build(
            type: .montee,
            name: "Col de la Croix",
            lookaheadStats: stats
        )

        let message = try #require(result)
        #expect(message.contains("Col de la Croix"))
    }

    // MARK: - Descente

    @Test
    func descente_generatesCorrectMessage() throws {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .descending,
            distance: 2500,
            elevationGain: 0,
            elevationLoss: 350,
            averageSlope: -0.14
        )

        let result = AnnouncementBuilder.build(
            type: .descente,
            name: nil,
            lookaheadStats: stats
        )

        let message = try #require(result)
        #expect(message.contains("Descente"))
        #expect(message.contains("2 virgule 5 kilomètres"))
        #expect(message.contains("14 pourcent"))
        #expect(message.contains("350 mètres de dénivelé négatif"))
    }

    // MARK: - Distance formatting

    @Test
    func shortDistance_formattedInMeters() throws {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .climbing,
            distance: 800,
            elevationGain: 80,
            elevationLoss: 0,
            averageSlope: 0.10
        )

        let result = AnnouncementBuilder.build(
            type: .montee,
            name: nil,
            lookaheadStats: stats
        )

        let message = try #require(result)
        #expect(message.contains("800 mètres"))
        #expect(!message.contains("kilomètres"))
    }

    @Test
    func wholeKilometer_noDecimal() throws {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .climbing,
            distance: 3000,
            elevationGain: 300,
            elevationLoss: 0,
            averageSlope: 0.10
        )

        let result = AnnouncementBuilder.build(
            type: .montee,
            name: nil,
            lookaheadStats: stats
        )

        let message = try #require(result)
        #expect(message.contains("3 kilomètres"))
        #expect(!message.contains("virgule"))
    }

    // MARK: - Plat

    @Test
    func plat_generatesCorrectMessage() throws {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .flat,
            distance: 2000,
            elevationGain: 10,
            elevationLoss: 5,
            averageSlope: 0.005
        )

        let result = AnnouncementBuilder.build(
            type: .plat,
            name: nil,
            lookaheadStats: stats
        )

        let message = try #require(result)
        #expect(message.contains("Plat"))
        #expect(message.contains("2 kilomètres"))
        #expect(!message.contains("pourcent"))
        #expect(!message.contains("dénivelé"))
    }

    @Test
    func plat_withName_includesName() throws {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .flat,
            distance: 800,
            elevationGain: 5,
            elevationLoss: 3,
            averageSlope: 0.002
        )

        let result = AnnouncementBuilder.build(
            type: .plat,
            name: "Plateau des Glières",
            lookaheadStats: stats
        )

        let message = try #require(result)
        #expect(message.contains("Plateau des Glières"))
        #expect(message.contains("800 mètres"))
    }

    // MARK: - Non terrain types return nil

    @Test
    func danger_returnsNil() {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .flat,
            distance: 2000,
            elevationGain: 10,
            elevationLoss: 5,
            averageSlope: 0.005
        )

        #expect(AnnouncementBuilder.build(type: .danger, name: nil, lookaheadStats: stats) == nil)
    }

    @Test
    func info_returnsNil() {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .flat,
            distance: 2000,
            elevationGain: 10,
            elevationLoss: 5,
            averageSlope: 0.005
        )

        #expect(AnnouncementBuilder.build(type: .info, name: nil, lookaheadStats: stats) == nil)
    }

    @Test
    func ravito_returnsNil() {
        let stats = ElevationProfileAnalyzer.LookaheadStats(
            terrainType: .climbing,
            distance: 2000,
            elevationGain: 200,
            elevationLoss: 0,
            averageSlope: 0.10
        )

        let result = AnnouncementBuilder.build(
            type: .ravito,
            name: nil,
            lookaheadStats: stats
        )

        #expect(result == nil)
    }

    // MARK: - Nil stats

    @Test
    func nilStats_returnsNil() {
        let result = AnnouncementBuilder.build(
            type: .montee,
            name: nil,
            lookaheadStats: nil
        )

        #expect(result == nil)
    }
}
