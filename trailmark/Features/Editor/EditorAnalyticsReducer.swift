import ComposableArchitecture

struct EditorAnalyticsReducer: Reducer {
    @Dependency(\.telemetry) var telemetry

    func reduce(into state: inout EditorStore.State, action: EditorStore.Action) -> Effect<EditorStore.Action> {
        switch action {
        case let .trailLoaded(detail):
            return .run { [telemetry] _ in
                telemetry.signal("Editor.opened", [
                    "milestoneCount": "\(detail.milestones.count)",
                    "isNewTrail": "false"
                ])
            }

        case .backgroundSaveCompleted(_, let milestones):
            return .run { [telemetry] _ in
                telemetry.signal("Editor.opened", [
                    "milestoneCount": "\(milestones.count)",
                    "isNewTrail": "true"
                ])
            }

        case .milestoneSheet(.presented(.saveButtonTapped)):
            guard let sheet = state.milestoneSheet else { return .none }
            if sheet.editingMilestone != nil {
                return .run { [telemetry] _ in
                    telemetry.signal("Milestone.edited", [
                        "type": sheet.selectedType.rawValue
                    ])
                }
            } else {
                return .run { [telemetry, count = state.milestones.count] _ in
                    telemetry.signal("Milestone.added", [
                        "type": sheet.selectedType.rawValue,
                        "totalCount": "\(count + 1)"
                    ])
                }
            }

        case .milestoneSheet(.presented(.deleteButtonTapped)):
            return .run { [telemetry, count = state.milestones.count] _ in
                telemetry.signal("Milestone.deleted", [
                    "remainingCount": "\(max(0, count - 1))"
                ])
            }

        case .milestoneSheet(.presented(.previewTTSTapped)):
            return .run { [telemetry] _ in
                telemetry.signal("Milestone.ttsPreview", [:])
            }

        case .elevationProfile(.delegate(.profileTapped(_))):
            guard !state.isPremium && state.milestones.count >= 10 else { return .none }
            return .run { [telemetry] _ in
                telemetry.signal("Paywall.shown", ["source": "milestoneLimit"])
            }

        default:
            return .none
        }
    }
}
