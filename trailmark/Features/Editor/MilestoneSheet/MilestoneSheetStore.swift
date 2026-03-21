import Foundation
import ComposableArchitecture

@Reducer
struct MilestoneSheetStore {
    enum Step: Equatable, Sendable {
        case announcementPreview
        case editing
    }

    @ObservableState
    struct State: Equatable, Sendable, Identifiable {
        var id: UUID = UUID()
        var editingMilestone: Milestone?
        var pointIndex: Int
        var latitude: Double
        var longitude: Double
        var elevation: Double
        var distance: Double
        var autoMessage: String?
        var step: Step = .announcementPreview

        // Child states
        var announcementPreview: AnnouncementPreviewStore.State?
        var edit: MilestoneEditStore.State

        var isEditing: Bool { editingMilestone != nil }

        var effectiveStep: Step {
            if autoMessage == nil || isEditing { return .editing }
            return step
        }

        init(
            editingMilestone: Milestone? = nil,
            pointIndex: Int,
            latitude: Double,
            longitude: Double,
            elevation: Double,
            distance: Double,
            selectedType: MilestoneType,
            personalMessage: String,
            name: String,
            autoMessage: String? = nil,
            useAutoAnnouncement: Bool = false,
            step: Step = .announcementPreview
        ) {
            self.editingMilestone = editingMilestone
            self.pointIndex = pointIndex
            self.latitude = latitude
            self.longitude = longitude
            self.elevation = elevation
            self.distance = distance
            self.autoMessage = autoMessage
            self.step = step

            // Init child states
            if let autoMessage {
                self.announcementPreview = AnnouncementPreviewStore.State(autoMessage: autoMessage)
            }
            self.edit = MilestoneEditStore.State(
                selectedType: selectedType,
                personalMessage: useAutoAnnouncement ? (autoMessage ?? "") : personalMessage,
                name: name,
                isEditing: editingMilestone != nil,
                distance: distance,
                elevation: elevation
            )
        }
    }

    enum Action: Equatable {
        case announcementPreview(AnnouncementPreviewStore.Action)
        case edit(MilestoneEditStore.Action)

        // Forwarded from parent (EditorStore intercepts these)
        case saveButtonTapped
        case deleteButtonTapped
        case dismissTapped
        case typeSelected(MilestoneType)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.edit, action: \.edit) {
            MilestoneEditStore()
        }

        Reduce { state, action in
            switch action {
            // MARK: - AnnouncementPreview delegates
            case let .announcementPreview(.delegate(.choseAutoMessage(message))):
                state.edit.personalMessage = message
                state.step = .editing
                return .none

            case .announcementPreview(.delegate(.choseWriteOwn)):
                state.edit.personalMessage = ""
                state.step = .editing
                return .none

            case .announcementPreview(.delegate(.unlockRequested)):
                // TODO: trigger paywall via parent
                return .none

            case .announcementPreview:
                return .none

            // MARK: - Edit forwarding
            case .edit(.saveButtonTapped):
                return .send(.saveButtonTapped)

            case .edit(.deleteButtonTapped):
                return .send(.deleteButtonTapped)

            case .edit(.dismissTapped):
                return .send(.dismissTapped)

            case let .edit(.typeSelected(type)):
                return .send(.typeSelected(type))

            case .edit:
                return .none

            // MARK: - Parent-facing actions (handled by EditorStore)
            case .saveButtonTapped, .deleteButtonTapped, .dismissTapped, .typeSelected:
                return .none
            }
        }
        .ifLet(\.announcementPreview, action: \.announcementPreview) {
            AnnouncementPreviewStore()
        }
    }
}
