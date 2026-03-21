import SwiftUI
import ComposableArchitecture

struct MilestoneEditView: View {
    @Bindable var store: StoreOf<MilestoneEditStore>
    @Namespace private var typeIndicator

    var body: some View {
        VStack(alignment: .leading) {
            sectionLabel("TYPE")

            typeCardsSelector(selectedType: store.selectedType)
                .padding(.top, 8)

            sectionLabel("ANNONCE VOCALE")
                .padding(.top, 14)

            messageTextField(placeholder: messagePlaceholder)
                .padding(.top, 8)

            listenButton
                .padding(.top, 12)

            sectionLabel("NOM (OPTIONNEL)")
                .padding(.top, 14)

            TextField("ex: Col de la Croix", text: $store.name)
                .font(.body)
                .foregroundStyle(TM.textPrimary)
                .padding(12)
                .background(TM.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(TM.border, lineWidth: 1)
                }
                .padding(.top, 8)
        }
        .padding(16)
        .onAppear {
            store.send(.onAppear)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(TM.textMuted)
    }

    private func messageTextField(placeholder: String) -> some View {
        TextField(
            placeholder,
            text: $store.personalMessage,
            axis: .vertical
        )
        .lineLimit(3...5)
        .font(.body)
        .foregroundStyle(TM.textPrimary)
        .padding(12)
        .background(TM.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(TM.border, lineWidth: 1)
        }
    }

    private var isListenDisabled: Bool {
        store.personalMessage.isEmpty
    }

    private var listenButton: some View {
        Button(store.isPlayingPreview ? "Arrêter" : "Écouter", systemImage: store.isPlayingPreview ? "stop.fill" : "speaker.wave.2.fill") {
            Haptic.light.trigger()
            if store.isPlayingPreview {
                store.send(.stopTTSTapped)
            } else {
                store.send(.previewTTSTapped)
            }
        }
        .secondaryButton(size: .large, width: .flexible, shape: .capsule)
        .disabled(isListenDisabled)
        .accessibilityLabel(store.isPlayingPreview ? "Arrêter la lecture" : "Écouter l'annonce")
    }

    private var messagePlaceholder: String {
        switch store.selectedType {
        case .ravito: "ex: Ravitaillement, prenez à gauche\u{2026}"
        case .danger: "ex: Attention, passage technique\u{2026}"
        case .info: "ex: Belle vue sur la vallée\u{2026}"
        case .plat: "ex: Portion plate, relancez\u{2026}"
        case .montee, .descente: "Votre annonce vocale\u{2026}"
        }
    }

    private func typeCardsSelector(selectedType: MilestoneType) -> some View {
        HStack(spacing: 0) {
            ForEach(MilestoneType.allCases, id: \.self) { (type: MilestoneType) in
                let isSelected = selectedType == type

                Button {
                    Haptic.selection.trigger()
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        store.send(.typeSelected(type))
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? type.color : TM.textMuted)
                            .frame(width: 20, height: 20)

                        Text(type.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isSelected ? TM.textPrimary : TM.textMuted)
                            .frame(height: 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(type.color.opacity(0.12))
                                .matchedGeometryEffect(id: "typeBackground", in: typeIndicator)
                        }
                    }
                }
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}

// MARK: - Preview

#Preview("Milestone Edit") {
    MilestoneEditView(
        store: Store(
            initialState: MilestoneEditStore.State(
                selectedType: .montee,
                personalMessage: "Montée. 1 virgule 8 kilomètres à 12 pourcent.",
                name: "",
                isEditing: false,
                distance: 3500,
                elevation: 2350
            )
        ) { MilestoneEditStore() }
    )
    .background(TM.bgCard)
}
