import SwiftUI
import ComposableArchitecture

struct RunView: View {
    let store: StoreOf<RunFeature>

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
        }
        .navigationBarHidden(true)
        .onAppear {
            store.send(.onAppear)
        }
    }

    // MARK: - Pre-Run View

    private func preRunView(detail: TrailDetail) -> some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    store.send(.backTapped)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Retour")
                    }
                    .font(.caption)
                    .foregroundStyle(TM.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

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

#Preview {
    RunView(
        store: Store(initialState: RunFeature.State(trailId: 1)) {
            RunFeature()
        }
    )
    .preferredColorScheme(.dark)
}
