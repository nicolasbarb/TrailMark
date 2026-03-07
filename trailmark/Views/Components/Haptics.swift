import UIKit

// MARK: - Haptic Feedback Helpers

enum Haptic {
    case light
    case medium
    case heavy
    case selection
    case success
    case warning
    case error

    // Reuse generators to avoid allocation on every call
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    func trigger() {
        switch self {
        case .light:
            Self.lightGenerator.impactOccurred()
        case .medium:
            Self.mediumGenerator.impactOccurred()
        case .heavy:
            Self.heavyGenerator.impactOccurred()
        case .selection:
            Self.selectionGenerator.selectionChanged()
        case .success:
            Self.notificationGenerator.notificationOccurred(.success)
        case .warning:
            Self.notificationGenerator.notificationOccurred(.warning)
        case .error:
            Self.notificationGenerator.notificationOccurred(.error)
        }
    }

    /// Pre-warm the Taptic Engine for lower latency on the next trigger.
    func prepare() {
        switch self {
        case .light: Self.lightGenerator.prepare()
        case .medium: Self.mediumGenerator.prepare()
        case .heavy: Self.heavyGenerator.prepare()
        case .selection: Self.selectionGenerator.prepare()
        case .success, .warning, .error: Self.notificationGenerator.prepare()
        }
    }
}
