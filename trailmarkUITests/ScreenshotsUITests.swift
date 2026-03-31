//
//  ScreenshotsUITests.swift
//  trailmarkUITests
//
//  Automated screenshots for App Store & marketing.
//  Each test launches the app on a specific screen via launch arguments.
//  No navigation needed — the app reads --screen=xxx and displays it directly.
//  Each screen is captured in both light and dark mode.
//

import XCTest

@MainActor
final class ScreenshotsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Dark Mode

    func testScreenshotListe_Dark() {
        launchApp(screen: "liste", style: .dark)
        snapshot("01_liste_dark")
    }

    func testScreenshotImport_Dark() {
        launchApp(screen: "import", style: .dark)
        snapshot("02_import_dark")
    }

    func testScreenshotEditor_Dark() {
        launchApp(screen: "editor", style: .dark)
        snapshot("03_editor_dark")
    }

    func testScreenshotRunReady_Dark() {
        launchApp(screen: "run_ready", style: .dark)
        snapshot("04_run_ready_dark")
    }

    func testScreenshotRunActive_Dark() {
        launchApp(screen: "run_active", style: .dark)
        snapshot("05_run_active_dark")
    }

    // MARK: - Light Mode

    func testScreenshotListe_Light() {
        launchApp(screen: "liste", style: .light)
        snapshot("01_liste_light")
    }

    func testScreenshotImport_Light() {
        launchApp(screen: "import", style: .light)
        snapshot("02_import_light")
    }

    func testScreenshotEditor_Light() {
        launchApp(screen: "editor", style: .light)
        snapshot("03_editor_light")
    }

    func testScreenshotRunReady_Light() {
        launchApp(screen: "run_ready", style: .light)
        snapshot("04_run_ready_light")
    }

    func testScreenshotRunActive_Light() {
        launchApp(screen: "run_active", style: .light)
        snapshot("05_run_active_light")
    }

    // MARK: - Helper

    private enum Style: String {
        case light, dark
    }

    @discardableResult
    private func launchApp(screen: String, style: Style) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["--screenshot", "--screen=\(screen)", "--style=\(style.rawValue)"]
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
        return app
    }
}
