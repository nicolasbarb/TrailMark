import Foundation
import Testing
@testable import trailmark

struct AnnouncementBuilderTests {

    // MARK: - Climb

    @Test
    func climb_generatesMessage() throws {
        let result = AnnouncementBuilder.build(
            type: .climb,
            distance: 1800,
            elevation: 215,
            slope: 0.12
        )

        let message = try #require(result)
        #expect(message.contains("12%"))
        #expect(message.contains("215"))
    }

    // MARK: - Descent

    @Test
    func descent_generatesMessage() throws {
        let result = AnnouncementBuilder.build(
            type: .descent,
            distance: 2500,
            elevation: 350,
            slope: -0.14
        )

        let message = try #require(result)
        #expect(message.contains("14%"))
        #expect(message.contains("350"))
    }

    // MARK: - Distance formatting

    @Test
    func shortDistance_formattedInMeters() {
        let result = AnnouncementBuilder.formatDistance(800)
        #expect(result == "800 m")
    }

    @Test
    func wholeKilometer_noDecimal() {
        let result = AnnouncementBuilder.formatDistance(3000)
        #expect(result == "3 km")
    }

    @Test
    func decimalKilometer_hasDecimal() {
        let result = AnnouncementBuilder.formatDistance(1800)
        #expect(result.contains("km"))
        #expect(result.contains("8")) // 1.8 or 1,8 depending on locale
    }

    // MARK: - Flat

    @Test
    func flat_generatesMessage() throws {
        let result = AnnouncementBuilder.build(
            type: .flat,
            distance: 2000,
            elevation: 0,
            slope: 0.005
        )

        let message = try #require(result)
        #expect(message.contains("2 km"))
        #expect(!message.contains("%"))
    }

    // MARK: - Non terrain types return nil

    @Test
    func danger_returnsNil() {
        #expect(AnnouncementBuilder.build(type: .danger, distance: 2000, elevation: 0, slope: 0) == nil)
    }

    @Test
    func info_returnsNil() {
        #expect(AnnouncementBuilder.build(type: .info, distance: 2000, elevation: 0, slope: 0) == nil)
    }

    @Test
    func aidStation_returnsNil() {
        #expect(AnnouncementBuilder.build(type: .aidStation, distance: 2000, elevation: 200, slope: 0.10) == nil)
    }
}
