import SwiftUI
import ComposableArchitecture

struct RunView: View {
    let store: StoreOf<RunFeature>

    // Debug tap detection
    #if DEBUG
    @State private var tapCount = 0
    @State private var lastTapTime: Date?
    #endif

    var body: some View {
        ZStack {
            TM.bgPrimary.ignoresSafeArea()

            if let detail = store.trailDetail {
                if store.isRunning {
                    runningView(detail: detail)
                } else {
                    preRunView(detail: detail)
                }
            } else {
                ProgressView()
                    .tint(TM.accent)
            }

            // Debug overlay
            #if DEBUG
            if store.showDebugView {
                debugOverlay
            }
            #endif
        }
        .contentShape(Rectangle())
        #if DEBUG
        .onTapGesture {
            guard store.isRunning else { return }
            handleDebugTap()
        }
        #endif
        .onAppear {
            store.send(.onAppear)
        }
    }

    #if DEBUG
    private func handleDebugTap() {
        let now = Date()

        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < 1.5 {
            tapCount += 1
        } else {
            tapCount = 1
        }

        lastTapTime = now

        if tapCount >= 5 {
            store.send(.toggleDebugView)
            tapCount = 0
        }
    }
    #endif

    // MARK: - Debug Overlay

    #if DEBUG
    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundStyle(TM.danger)
                Text("DEBUG")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TM.danger)
                Spacer()
                Button {
                    store.send(.toggleDebugView)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TM.textMuted)
                }
            }

            Divider()
                .background(TM.border)

            debugRow(label: "GPS updates", value: "\(store.locationUpdateCount)")

            if let lat = store.currentLatitude, let lon = store.currentLongitude {
                debugRow(label: "Position", value: "\(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))")
            } else {
                debugRow(label: "Position", value: "—")
            }

            if let distance = store.closestMilestoneDistance {
                debugRow(label: "Prochain jalon", value: "\(distance)m")
            } else {
                debugRow(label: "Prochain jalon", value: "—")
            }

            if let message = store.closestMilestoneMessage {
                debugRow(label: "Prochain message", value: String(message.prefix(40)) + (message.count > 40 ? "..." : ""))
            }

            debugRow(label: "Jalons déclenchés", value: "\(store.triggeredMilestoneIds.count)/\(store.trailDetail?.milestones.count ?? 0)")

            if let tts = store.currentTTSMessage {
                debugRow(label: "TTS", value: "🔊 " + String(tts.prefix(30)))
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TM.danger.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 60)
    }

    private func debugRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(TM.textMuted)
            Spacer()
            Text(value)
                .foregroundStyle(TM.textPrimary)
        }
    }
    #endif

    // MARK: - Pre-Run View

    private func preRunView(detail: TrailDetail) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Trail info
            VStack(spacing: 8) {
                Text(detail.trail.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TM.textPrimary)
                    .multilineTextAlignment(.center)

                Text("\(detail.distKm) km · \(detail.trail.dPlus)m D+ · \(detail.milestoneCount) jalons")
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
            }

            // Play button
            playButton
                .padding(.top, 36)

            // Instructions
            VStack(spacing: 8) {
                Text("Lancer le guidage")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TM.textPrimary)

                Text("Rangez le téléphone dans votre poche.\nLes jalons seront annoncés vocalement.")
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.top, 36)

            // Permission denied warning
            if store.authorizationDenied {
                permissionDeniedBanner
                    .padding(.top, 20)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var playButton: some View {
        Button {
            store.send(.startButtonTapped)
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(TM.accent.opacity(0.2), lineWidth: 2)
                    .frame(width: 116, height: 116)

                // Inner button
                Circle()
                    .fill(TM.accentGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: TM.accent.opacity(0.4), radius: 24, y: 8)

                Image(systemName: "play.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
        }
    }

    private var permissionDeniedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.slash")
                .foregroundStyle(TM.danger)
            Text("Accès à la localisation refusé. Activez-le dans les réglages.")
                .font(.caption)
                .foregroundStyle(TM.danger)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(TM.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Running View

    private func runningView(detail: TrailDetail) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Active indicator
            ZStack {
                Circle()
                    .fill(TM.success.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(TM.success.opacity(0.3), lineWidth: 2)
                    )

                Circle()
                    .fill(TM.success)
                    .frame(width: 20, height: 20)
                    .shadow(color: TM.success.opacity(0.5), radius: 12)
            }

            // Text
            VStack(spacing: 8) {
                Text("Guidage en cours")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TM.textPrimary)

                Text(detail.trail.name)
                    .font(.subheadline)
                    .foregroundStyle(TM.textMuted)

                Text("Les jalons sont annoncés automatiquement\npar GPS. Vous pouvez ranger le téléphone.")
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 8)
            }
            .padding(.top, 24)

            // TTS bubble
            if let message = store.currentTTSMessage {
                ttsBubble(message: message)
                    .padding(.top, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.spring(duration: 0.3), value: store.currentTTSMessage)
            }

            Spacer()

            // Stop button
            Button {
                store.send(.stopButtonTapped)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                    Text("Arrêter le guidage")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(TM.danger, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
    }

    private func ttsBubble(message: String) -> some View {
        HStack(spacing: 0) {
            // Left accent bar
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14)
                .fill(TM.accent)
                .frame(width: 4)

            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(TM.accent)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TM.textPrimary)
                    .lineLimit(3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(TM.bgPrimary.opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(TM.accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
        .padding(.horizontal, 28)
    }
}

// MARK: - Preview Data

private enum PreviewData {
    static let trail = Trail(
        id: 1,
        name: "Tour du Mont Blanc",
        createdAt: Date(),
        distance: 42_500,
        dPlus: 2_850
    )

    static let milestones: [Milestone] = [
        Milestone(
            id: 1,
            trailId: 1,
            pointIndex: 100,
            latitude: 45.9,
            longitude: 6.87,
            elevation: 1200,
            distance: 5000,
            type: .montee,
            message: "Début de la montée vers le Col de Voza"
        ),
        Milestone(
            id: 2,
            trailId: 1,
            pointIndex: 200,
            latitude: 45.92,
            longitude: 6.88,
            elevation: 1650,
            distance: 10000,
            type: .ravito,
            message: "Ravitaillement aux Contamines dans 500 mètres"
        ),
    ]

    static let trailDetail = TrailDetail(
        trail: trail,
        trackPoints: [],
        milestones: milestones
    )
}

#Preview("Pré-démarrage") {
    NavigationStack {
        RunView(
            store: Store(
                initialState: RunFeature.State(
                    trailId: 1,
                    trailDetail: PreviewData.trailDetail,
                    isRunning: false
                )
            ) {
                RunFeature()
            }
        )
    }
}

#Preview("Guidage en cours") {
    RunView(
        store: Store(
            initialState: RunFeature.State(
                trailId: 1,
                trailDetail: PreviewData.trailDetail,
                isRunning: true
            )
        ) {
            RunFeature()
        }
    )
}

#Preview("Avec annonce TTS") {
    RunView(
        store: Store(
            initialState: RunFeature.State(
                trailId: 1,
                trailDetail: PreviewData.trailDetail,
                isRunning: true,
                currentTTSMessage: "Début de la montée vers le Col de Voza. Courage, 450 mètres de dénivelé positif."
            )
        ) {
            RunFeature()
        }
    )
}

#Preview("Permission refusée") {
    RunView(
        store: Store(
            initialState: RunFeature.State(
                trailId: 1,
                trailDetail: PreviewData.trailDetail,
                isRunning: false,
                authorizationDenied: true
            )
        ) {
            RunFeature()
        }
    )
}

#Preview("Debug View") {
    RunView(
        store: Store(
            initialState: RunFeature.State(
                trailId: 1,
                trailDetail: PreviewData.trailDetail,
                isRunning: true,
                triggeredMilestoneIds: [1],
                showDebugView: true,
                currentLatitude: 45.832156,
                currentLongitude: 6.865234,
                closestMilestoneDistance: 127,
                closestMilestoneMessage: "Ravitaillement aux Contamines dans 500 mètres",
                locationUpdateCount: 42
            )
        ) {
            RunFeature()
        }
    )
}
