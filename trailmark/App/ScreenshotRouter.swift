import SwiftUI
import ComposableArchitecture
import Dependencies

/// Router for automated screenshots.
/// Reads --screen=xxx from launch arguments and displays the corresponding screen
/// with UTMB sample data loaded from the bundle.
struct ScreenshotRouter: View {
    let screen: String
    let colorScheme: ColorScheme

    init() {
        self.screen = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--screen=") }?
            .replacingOccurrences(of: "--screen=", with: "")
            ?? "liste"

        let style = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--style=") }?
            .replacingOccurrences(of: "--style=", with: "")
            ?? "dark"
        self.colorScheme = style == "light" ? .light : .dark
    }

    var body: some View {
        Group {
            switch screen {
            case "liste":
                screenshotTrailList()
            case "import":
                screenshotImport()
            case "editor":
                screenshotEditor()
            case "run_ready":
                screenshotRunReady()
            case "run_active":
                screenshotRunActive()
            default:
                Text("Unknown screen: \(screen)")
            }
        }
        .preferredColorScheme(colorScheme)
    }

    // MARK: - Trail List

    private func screenshotTrailList() -> some View {
        NavigationStack {
            TrailListView(
                store: Store(
                    initialState: {
                        var state = TrailListStore.State()
                        state.isLoading = false
                        state.trails = Self.sampleTrailListItems()
                        state.$isPremium.withLock { $0 = true }
                        // Prevent first-visit paywall and review prompts
                        state.$trailListVisitCount.withLock { $0 = 10 }
                        state.$hasRequestedReview.withLock { $0 = true }
                        return state
                    }()
                ) {
                    EmptyReducer()
                }
            )
            .navigationBarBackButtonHidden()
        }
    }

    // MARK: - Import

    private func screenshotImport() -> some View {
        let (trail, trackPoints, milestones) = Self.parseSampleGPX()
        return ImportView(
            store: Store(
                initialState: {
                    var state = ImportStore.State()
                    state.phase = .result
                    state.parsedTrail = trail
                    state.parsedTrackPoints = trackPoints
                    state.detectedMilestones = milestones
                    state.$isPremium.withLock { $0 = true }
                    state.profileAnimationFinished = true
                    state.detectionFinished = true
                    return state
                }()
            ) {
                ImportStore()
            }
        )
    }

    // MARK: - Editor

    private func screenshotEditor() -> some View {
        let (trail, trackPoints, milestones) = Self.parseSampleGPX()
        let detail = TrailDetail(
            trail: trail,
            trackPoints: trackPoints,
            milestones: milestones
        )
        return NavigationStack {
            EditorView(
                store: Store(
                    initialState: {
                        var state = EditorStore.State(trailId: trail.id ?? 1)
                        state.trailDetail = detail
                        state.milestones = milestones
                        state.originalMilestones = milestones
                        state.$isPremium.withLock { $0 = true }
                        return state
                    }()
                ) {
                    EditorStore()
                }
            )
            .navigationBarBackButtonHidden()
        }
    }

    // MARK: - Run Ready

    private func screenshotRunReady() -> some View {
        let (trail, trackPoints, milestones) = Self.parseSampleGPX()
        let detail = TrailDetail(
            trail: trail,
            trackPoints: trackPoints,
            milestones: milestones
        )
        return NavigationStack {
            RunView(
                store: Store(
                    initialState: {
                        var state = RunStore.State(trailId: trail.id ?? 1)
                        state.trailDetail = detail
                        state.isRunning = false
                        return state
                    }()
                ) {
                    RunStore()
                }
            )
            .navigationBarBackButtonHidden()
        }
    }

    // MARK: - Run Active

    private func screenshotRunActive() -> some View {
        let (trail, trackPoints, milestones) = Self.parseSampleGPX()
        let detail = TrailDetail(
            trail: trail,
            trackPoints: trackPoints,
            milestones: milestones
        )
        return NavigationStack {
            RunView(
                store: Store(
                    initialState: {
                        var state = RunStore.State(trailId: trail.id ?? 1)
                        state.trailDetail = detail
                        state.isRunning = true
                        state.currentTTSMessage = "Montée de 450 mètres sur 3 kilomètres. Gère ton effort, reste régulier."
                        return state
                    }()
                ) {
                    RunStore()
                }
            )
            .navigationBarBackButtonHidden()
        }
    }

    // MARK: - Sample Data

    @MainActor
    private static func parseSampleGPX() -> (Trail, [TrackPoint], [Milestone]) {
        let (points, dPlus) = try! GPXParser.parseFromBundle(resource: "utmb-preview", extension: "gpx")
        let totalDistance = points.last?.distance ?? 0

        let trail = Trail(
            id: 1,
            name: "UTMB",
            createdAt: Date(),
            distance: totalDistance,
            dPlus: dPlus
        )

        let trackPoints = points.enumerated().map { index, point in
            TrackPoint(
                id: Int64(index + 1),
                trailId: 1,
                index: index,
                latitude: point.latitude,
                longitude: point.longitude,
                elevation: point.elevation,
                distance: point.distance
            )
        }

        let milestones = MilestoneDetector.detect(from: trackPoints, trailId: 1)

        return (trail, trackPoints, milestones)
    }

    private static func sampleTrailListItems() -> [TrailListItem] {
        let (trail, _, milestones) = parseSampleGPX()
        return [
            TrailListItem(trail: trail, milestoneCount: milestones.count)
        ]
    }
}
