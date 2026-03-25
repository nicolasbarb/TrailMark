import SwiftUI
import ComposableArchitecture

struct LanguageView: View {
    let store: StoreOf<LanguageStore>

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "globe")
                    Text("settings.language.current")
                    Spacer()
                    Text(store.currentLanguage.capitalized)
                        .foregroundStyle(TM.textMuted)
                }
            } footer: {
                Text("settings.language.footer")
                    .font(.footnote)
                    .foregroundStyle(TM.textMuted)
            }
            .listRowBackground(TM.bgSecondary)

            Section {
                Button {
                    store.send(.openSettingsTapped)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: "gear")
                        Text("settings.language.openSettings")
                            .foregroundStyle(TM.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TM.textMuted)
                    }
                }
            }
            .listRowBackground(TM.bgSecondary)
        }
        .listStyle(.automatic)
        .scrollContentBackground(.hidden)
        .background(TM.bgPrimary)
        .navigationTitle("settings.language.title")
        .navigationBarTitleDisplayMode(.large)
        .contentMargins(.top, 16)
    }
}

#Preview {
    NavigationStack {
        LanguageView(
            store: Store(initialState: LanguageStore.State()) {
                LanguageStore()
            }
        )
    }
}
