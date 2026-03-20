import ComposableArchitecture

struct ImportAnalyticsReducer: Reducer {
    @Dependency(\.telemetry) var telemetry

    func reduce(into state: inout ImportStore.State, action: ImportStore.Action) -> Effect<ImportStore.Action> {
        switch action {
        case .uploadZoneTapped:
            return .run { [telemetry] _ in
                telemetry.signal("Import.started", [:])
            }

        case .fileSelected:
            return .run { [telemetry] _ in
                telemetry.signal("Import.fileSelected", [:])
            }

        case let .analysisCompleted(trail, trackPoints, _):
            return .run { [telemetry] _ in
                telemetry.signal("Import.parseSucceeded", [
                    "pointCount": "\(trackPoints.count)",
                    "distance": "\(Int(trail.distance))",
                    "dPlus": "\(trail.dPlus)"
                ])
            }

        case let .importFailed(error):
            return .run { [telemetry] _ in
                telemetry.signal("Import.parseFailed", ["error": error])
            }

        case let .importCompleted(pendingData):
            return .run { [telemetry] _ in
                telemetry.signal("Import.completed", [
                    "withMilestones": pendingData.detectedMilestones.isEmpty ? "false" : "true"
                ])
            }

        case .dismissTapped:
            return .run { [telemetry] _ in
                telemetry.signal("Import.dismissed", [:])
            }

        case .unlockTapped:
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.shown", ["source": "import"])
            }

        default:
            return .none
        }
    }
}
