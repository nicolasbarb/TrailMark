import SwiftUI
import ComposableArchitecture

struct MilestoneSheetView: View {
    @Bindable var store: StoreOf<MilestoneSheetStore>
    @Namespace private var typeIndicator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Type selector (horizontal cards from Approach 3)
                    sectionLabel("TYPE")

                    typeCardsSelector(selectedType: store.selectedType)
                        .padding(.top, 8)

                    // MARK: - Message Section (conditional layout)
                    if let autoMessage = store.autoMessage {
                        // montee/descente: auto block + personal complement
                        HStack(spacing: 6) {
                            sectionLabel("ANNONCE VOCALE")
                            proBadge
                        }
                        .padding(.top, 14)

                        // Auto-generated text block (read-only)
                        Text(autoMessage)
                            .font(.body)
                            .foregroundStyle(TM.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 10))
                            .opacity(store.isPremium ? 1 : 0.7)
                            .padding(.top, 8)

                        sectionLabel("COMPLEMENT PERSO")
                            .padding(.top, 14)

                        TextField(
                            "Ajouter un message personnel\u{2026}",
                            text: $store.personalMessage,
                            axis: .vertical
                        )
                        .lineLimit(3...5)
                        .font(.body)
                        .foregroundStyle(TM.textPrimary)
                        .padding(12)
                        .background(TM.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(TM.border, lineWidth: 1)
                        )
                        .padding(.top, 8)
                    } else {
                        // Non montee/descente: plain message field
                        sectionLabel("MESSAGE TTS")
                            .padding(.top, 14)

                        TextField(
                            messagePlaceholder,
                            text: $store.personalMessage,
                            axis: .vertical
                        )
                        .lineLimit(3...5)
                        .font(.body)
                        .foregroundStyle(TM.textPrimary)
                        .padding(12)
                        .background(TM.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(TM.border, lineWidth: 1)
                        )
                        .padding(.top, 8)
                    }

                    // Full-width listen button
                    listenButton
                        .padding(.top, 12)

                    // Name
                    sectionLabel("NOM (OPTIONNEL)")
                        .padding(.top, 14)

                    TextField("ex: Col de la Croix", text: $store.name)
                        .font(.body)
                        .foregroundStyle(TM.textPrimary)
                        .padding(12)
                        .background(TM.bgPrimary, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(TM.border, lineWidth: 1)
                        )
                        .padding(.top, 8)

                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark", role: .cancel) {
                        Haptic.light.trigger()
                        store.send(.dismissTapped)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(store.isEditing ? "Modifier" : "Nouveau repère")
                            .font(.headline)
                        PointStatsView(distanceMeters: store.distance, altitudeMeters: store.elevation)
                    }
                }

                if store.isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Supprimer", systemImage: "trash", role: .destructive) {
                            Haptic.warning.trigger()
                            store.send(.deleteButtonTapped)
                        }
                        .tint(TM.danger)
                    }

                    ToolbarSpacer(.fixed, placement: .confirmationAction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider", systemImage: "checkmark") {
                        Haptic.success.trigger()
                        store.send(.saveButtonTapped)
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(TM.textMuted)
    }

    // MARK: - PRO Badge

    private var proBadge: some View {
        HStack(spacing: 4) {
            if !store.isPremium {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.black)
            }
            Text("PRO")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(TM.accent, in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Listen Button

    private var isListenDisabled: Bool {
        (store.autoMessage ?? "").isEmpty && store.personalMessage.isEmpty
    }

    private var listenButton: some View {
        Button {
            Haptic.light.trigger()
            if store.isPlayingPreview {
                store.send(.stopTTSTapped)
            } else {
                store.send(.previewTTSTapped)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.isPlayingPreview ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(store.isPlayingPreview ? "Arrêter" : "Écouter l'annonce")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isListenDisabled ? TM.textMuted : TM.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isListenDisabled ? TM.border : TM.accent, lineWidth: 1)
            )
        }
        .disabled(isListenDisabled)
        .accessibilityLabel(store.isPlayingPreview ? "Arrêter la lecture" : "Écouter l'annonce")
    }

    // MARK: - Message Placeholder

    private var messagePlaceholder: String {
        switch store.selectedType {
        case .ravito: "ex: Ravitaillement, prenez à gauche\u{2026}"
        case .danger: "ex: Attention, passage technique\u{2026}"
        case .info: "ex: Belle vue sur la vallée\u{2026}"
        case .plat: "ex: Portion plate, relancez\u{2026}"
        case .montee, .descente: "Ajouter un message personnel\u{2026}"
        }
    }

    // MARK: - Type Selector

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

#Preview("Milestone Sheet") {
    MilestoneSheetView(
        store: Store(
            initialState: MilestoneSheetStore.State(
                editingMilestone: nil,
                pointIndex: 50,
                latitude: 45.0641,
                longitude: 6.4078,
                elevation: 2350,
                distance: 3500,
                selectedType: .montee,
                personalMessage: "",
                name: "",
                autoMessage: "Montée. 1 virgule 8 kilomètres à 12 pourcent. 215 mètres de dénivelé positif."
            )
        ) {
            MilestoneSheetStore()
        }
    )
    .presentationBackground(TM.bgCard)
}