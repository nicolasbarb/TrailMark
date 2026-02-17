import Foundation
import ComposableArchitecture
import UniformTypeIdentifiers

@Reducer
struct ImportFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var isImporting = false
        var isShowingFilePicker = false
        var error: String?
    }

    enum Action: Sendable {
        case uploadZoneTapped
        case filePickerDismissed
        case fileSelected(String) // URL path as String for Sendable
        case importCompleted(Trail)
        case importFailed(String)
        case dismissTapped
    }

    @Dependency(\.database) var database
    @Dependency(\.dismiss) var dismiss

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .uploadZoneTapped:
                state.isShowingFilePicker = true
                state.error = nil
                return .none

            case .filePickerDismissed:
                state.isShowingFilePicker = false
                return .none

            case let .fileSelected(urlPath):
                state.isImporting = true
                state.error = nil
                let url = URL(fileURLWithPath: urlPath)
                return .run { send in
                    do {
                        let (parsedPoints, dPlus) = try await MainActor.run { try GPXParser.parse(url: url) }
                        let trailName = GPXParser.trailName(from: url)
                        let totalDistance = parsedPoints.last?.distance ?? 0

                        var trail = Trail(
                            id: nil,
                            name: trailName,
                            createdAt: Date(),
                            distance: totalDistance,
                            dPlus: dPlus,
                            trailColor: .default
                        )

                        let trackPoints = parsedPoints.enumerated().map { index, point in
                            TrackPoint(
                                id: nil,
                                trailId: 0, // Will be set by database
                                index: index,
                                latitude: point.latitude,
                                longitude: point.longitude,
                                elevation: point.elevation,
                                distance: point.distance
                            )
                        }

                        trail = try await database.insertTrail(trail, trackPoints)
                        await send(.importCompleted(trail))
                    } catch let error as GPXParser.ParseError {
                        await send(.importFailed(error.localizedDescription))
                    } catch {
                        await send(.importFailed("Erreur lors de l'import: \(error.localizedDescription)"))
                    }
                }

            case .importCompleted:
                state.isImporting = false
                return .none

            case let .importFailed(message):
                state.isImporting = false
                state.error = message
                return .none

            case .dismissTapped:
                return .run { _ in
                    await dismiss()
                }
            }
        }
    }
}
