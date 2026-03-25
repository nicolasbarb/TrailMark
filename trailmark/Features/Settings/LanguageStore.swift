import Foundation
import ComposableArchitecture
import UIKit

@Reducer
struct LanguageStore {
    @ObservableState
    struct State: Equatable {
        var currentLanguage: String {
            let code = Bundle.main.preferredLocalizations.first ?? "en"
            return Locale.current.localizedString(forLanguageCode: code) ?? code
        }
    }

    enum Action: Equatable {
        case openSettingsTapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .openSettingsTapped:
                return .run { _ in
                    await UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
        }
    }
}
