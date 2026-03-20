import Foundation
import ComposableArchitecture
import CoreLocation

// MARK: - MilestoneSheet Reducer

@Reducer
struct MilestoneSheetStore {
    enum Step: Equatable, Sendable {
        case discovery
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
        var selectedType: MilestoneType
        var personalMessage: String
        var name: String
        var autoMessage: String? = nil
        var useAutoAnnouncement = false
        var step: Step = .discovery
        var isPlayingPreview = false
        @Shared(.inMemory("isPremium")) var isPremium = false

        var isEditing: Bool { editingMilestone != nil }

        // Si pas d'autoMessage ou en mode édition, aller directement à l'étape editing
        var effectiveStep: Step {
            if autoMessage == nil || isEditing { return .editing }
            return step
        }
    }

    static func buildFullMessage(
        autoMessage: String?,
        personalMessage: String,
        includeAuto: Bool
    ) -> String? {
        var parts: [String] = []
        if includeAuto, let auto = autoMessage, !auto.isEmpty {
            parts.append(auto)
        }
        if !personalMessage.isEmpty {
            parts.append(personalMessage)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case typeSelected(MilestoneType)
        case saveButtonTapped
        case deleteButtonTapped
        case dismissTapped
        case useAutoMessage
        case writeOwnMessage
        case previewTTSTapped
        case stopTTSTapped
        case ttsFinished
    }

    @Dependency(\.speech) var speech

    private enum CancelID { case ttsPreview }

    var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .typeSelected(let type):
                state.selectedType = type
                return .none
            case .saveButtonTapped:
                return .none
            case .deleteButtonTapped:
                return .none
            case .useAutoMessage:
                state.useAutoAnnouncement = true
                state.step = .editing
                return .none
            case .writeOwnMessage:
                state.useAutoAnnouncement = false
                state.step = .editing
                return .none
            case .dismissTapped:
                speech.stop()
                return .cancel(id: CancelID.ttsPreview)
            case .previewTTSTapped:
                guard !(state.autoMessage ?? "").isEmpty || !state.personalMessage.isEmpty else { return .none }
                state.isPlayingPreview = true
                let fullMessage = Self.buildFullMessage(
                    autoMessage: state.autoMessage,
                    personalMessage: state.personalMessage,
                    includeAuto: true
                )!
                return .run { send in
                    try? speech.configureAudioSession()
                    await speech.speak(fullMessage)
                    await send(.ttsFinished)
                }
                .cancellable(id: CancelID.ttsPreview)
            case .stopTTSTapped:
                state.isPlayingPreview = false
                speech.stop()
                return .cancel(id: CancelID.ttsPreview)
            case .ttsFinished:
                state.isPlayingPreview = false
                return .none
            }
        }
    }
}