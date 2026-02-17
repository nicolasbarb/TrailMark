import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct ImportView: View {
    @Bindable var store: StoreOf<ImportFeature>

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Text("TrailMark")
                        .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                        .foregroundStyle(TM.accent)

                    Text("ÉDITEUR DE JALONS GPS")
                        .font(.caption2)
                        .tracking(3)
                        .foregroundStyle(TM.textMuted)
                }

                // Upload zone
                uploadZone
                    .padding(.top, 48)

                // Error message
                if let error = store.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TM.danger)
                        .padding(.top, 12)
                }

                Spacer()

                // Back link
                Button {
                    store.send(.dismissTapped)
                } label: {
                    Text("Retour à mes parcours")
                        .font(.caption)
                        .foregroundStyle(TM.textMuted)
                        .underline()
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
        .fileImporter(
            isPresented: Binding(
                get: { store.isShowingFilePicker },
                set: { newValue in
                    if !newValue {
                        store.send(.filePickerDismissed)
                    }
                }
            ),
            allowedContentTypes: gpxContentTypes,
            onCompletion: { result in
                switch result {
                case .success(let url):
                    store.send(.fileSelected(url.path))
                case .failure:
                    store.send(.filePickerDismissed)
                }
            }
        )
    }

    // MARK: - Upload Zone

    private var uploadZone: some View {
        Button {
            store.send(.uploadZoneTapped)
        } label: {
            VStack(spacing: 16) {
                if store.isImporting {
                    ProgressView()
                        .tint(TM.accent)
                        .scaleEffect(1.2)
                } else {
                    // Icon
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 24))
                        .foregroundStyle(TM.accent)
                        .frame(width: 48, height: 48)
                        .background(TM.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    // Text
                    VStack(spacing: 4) {
                        Text("Importer un fichier GPX")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TM.textPrimary)

                        Text("Appuyez pour parcourir")
                            .font(.caption)
                            .foregroundStyle(TM.textMuted)
                    }

                    // Badge
                    Text(".GPX")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(TM.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(TM.accent.opacity(0.1), in: Capsule())
                }
            }
            .frame(maxWidth: 300)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(TM.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundStyle(TM.border)
            )
        }
        .disabled(store.isImporting)
    }

    // MARK: - Content Types

    private var gpxContentTypes: [UTType] {
        var types: [UTType] = [.xml]
        if let gpxType = UTType(filenameExtension: "gpx") {
            types.insert(gpxType, at: 0)
        }
        return types
    }
}

#Preview {
    ImportView(
        store: Store(initialState: ImportFeature.State()) {
            ImportFeature()
        }
    )
}
