import Foundation
import ComposableArchitecture

@Reducer
struct TrailListFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var trails: [TrailListItem] = []
        var isLoading = false
        @Presents var destination: Destination.State?
    }

    enum Action: Sendable {
        case onAppear
        case trailsLoaded([TrailListItem])
        case addButtonTapped
        case editTrailTapped(TrailListItem)
        case startTrailTapped(TrailListItem)
        case deleteTrailTapped(TrailListItem)
        case trailDeleted
        case navigateToEditor(Int64)
        case destination(PresentationAction<Destination.Action>)
    }

    @Dependency(\.database) var database

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let trails = try await database.fetchAllTrails()
                    await send(.trailsLoaded(trails))
                }

            case let .trailsLoaded(trails):
                state.isLoading = false
                state.trails = trails
                return .none

            case .addButtonTapped:
                state.destination = .importGPX(ImportFeature.State())
                return .none

            case let .editTrailTapped(item):
                guard let trailId = item.trail.id else { return .none }
                state.destination = .editor(EditorFeature.State(trailId: trailId))
                return .none

            case let .startTrailTapped(item):
                guard let trailId = item.trail.id else { return .none }
                state.destination = .run(RunFeature.State(trailId: trailId))
                return .none

            case let .deleteTrailTapped(item):
                guard let trailId = item.trail.id else { return .none }
                return .run { send in
                    try await database.deleteTrail(trailId)
                    await send(.trailDeleted)
                }

            case .trailDeleted:
                return .run { send in
                    let trails = try await database.fetchAllTrails()
                    await send(.trailsLoaded(trails))
                }

            case let .navigateToEditor(trailId):
                state.destination = .editor(EditorFeature.State(trailId: trailId))
                return .none

            case .destination(.presented(.importGPX(.importCompleted(let trail)))):
                state.destination = nil
                guard let trailId = trail.id else { return .none }
                // Navigate to editor after successful import
                return .run { [trailId] send in
                    // Small delay to allow sheet dismissal
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.navigateToEditor(trailId))
                }

            case .destination(.dismiss):
                // Reload trails when returning from any destination
                return .run { send in
                    let trails = try await database.fetchAllTrails()
                    await send(.trailsLoaded(trails))
                }

            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }

    // MARK: - Destination

    @Reducer
    struct Destination {
        @ObservableState
        enum State: Equatable, Sendable {
            case importGPX(ImportFeature.State)
            case editor(EditorFeature.State)
            case run(RunFeature.State)
        }

        enum Action: Sendable {
            case importGPX(ImportFeature.Action)
            case editor(EditorFeature.Action)
            case run(RunFeature.Action)
        }

        var body: some Reducer<State, Action> {
            Scope(state: \.importGPX, action: \.importGPX) {
                ImportFeature()
            }
            Scope(state: \.editor, action: \.editor) {
                EditorFeature()
            }
            Scope(state: \.run, action: \.run) {
                RunFeature()
            }
        }
    }
}
