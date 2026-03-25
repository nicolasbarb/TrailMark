import SwiftUI
import ComposableArchitecture

struct AnnouncementPreviewView: View {
    @Bindable var store: StoreOf<AnnouncementPreviewStore>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(TM.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("editor.announcementPreview.header")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(TM.textPrimary)
                    Text("editor.announcementPreview.subheader")
                        .font(.subheadline)
                        .foregroundStyle(TM.textTertiary)
                }
            }

            // Auto-generated text
            Text(store.autoMessage)
                .font(.body)
                .foregroundStyle(store.isPremium ? TM.textPrimary : TM.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    store.isPremium ? TM.bgPrimary.opacity(0.5) : Color.black.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(alignment: .topTrailing) {
                    if !store.isPremium {
                        ProBadge(isLockVisible: true)
                            .padding(8)
                    }
                }
                .padding(.bottom, 12)

            // Choice buttons
            VStack(spacing: 8) {
                if store.isPremium {
                    Button("editor.announcementPreview.useButton") {
                        store.send(.useAutoMessage)
                    }
                    .primaryButton(size: .large, width: .flexible, shape: .capsule)
                } else {
                    Button("common.unlockWithPro", systemImage: "lock.fill") {
                        store.send(.unlockTapped)
                    }
                    .primaryButton(size: .large, width: .flexible, shape: .capsule)
                }

                Button("editor.announcementPreview.writeManually") {
                    store.send(.writeOwnMessage)
                }
                .tertiaryButton(size: .large, tint: TM.textSecondary)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
    }
}

// MARK: - Previews

private let previewAutoMessage = "Montée. 1 virgule 8 kilomètres à 12 pourcent. 215 mètres de dénivelé positif."

#Preview("AnnouncementPreview — PRO") {
    AnnouncementPreviewView(
        store: Store(
            initialState: {
                var state = AnnouncementPreviewStore.State(autoMessage: previewAutoMessage)
                state.$isPremium.withLock { $0 = true }
                return state
            }()
        ) { AnnouncementPreviewStore() }
    )
    .background(TM.bgCard)
}

#Preview("AnnouncementPreview — Gratuit") {
    AnnouncementPreviewView(
        store: Store(
            initialState: {
                var state = AnnouncementPreviewStore.State(autoMessage: previewAutoMessage)
                state.$isPremium.withLock { $0 = false }
                return state
            }()
        ) { AnnouncementPreviewStore() }
    )
    .background(TM.bgCard)
}
