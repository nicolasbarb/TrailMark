import SwiftUI

// MARK: - Design System

/// Design tokens using Apple's native semantic colors
/// Following Human Interface Guidelines for dark mode
enum TM {
    // MARK: Backgrounds
    /// Main screen background - adapts to device (pure black on OLED)
    static let bgPrimary = Color(uiColor: .systemBackground)
    /// Cards, elevated surfaces
    static let bgSecondary = Color(uiColor: .secondarySystemBackground)
    /// Further elevated content
    static let bgTertiary = Color(uiColor: .tertiarySystemBackground)
    /// Card backgrounds (alias for consistency)
    static let bgCard = Color(uiColor: .secondarySystemBackground)

    // MARK: Text
    /// Primary content text
    static let textPrimary = Color.primary
    /// Secondary content, subtitles
    static let textSecondary = Color.secondary
    /// Tertiary text, units, labels
    static let textTertiary = Color(uiColor: .secondaryLabel)
    /// Disabled text, hints
    static let textMuted = Color(uiColor: .tertiaryLabel)

    // MARK: Accents
    /// App accent color - orange for trail/outdoor theme
    static let accent = Color.accentColor
    /// Darker accent variant
    static let accentDark = Color(uiColor: .systemOrange).opacity(0.85)
    /// GPS trace color - cyan for visibility
    static let trace = Color.cyan
    /// Trace glow effect
    static let traceGlow = Color.cyan.opacity(0.3)
    /// Borders and separators
    static let border = Color(uiColor: .separator)
    /// Error states
    static let danger = Color.red
    /// Success states
    static let success = Color.green

    // MARK: Gradients
    static let accentGradient = LinearGradient(
        colors: [accent, accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Milestone Type Colors

extension MilestoneType {
    var color: Color {
        switch self {
        case .climb: return .orange
        case .descent: return .cyan
        case .flat: return .green
        case .aidStation: return .purple
        case .danger: return .red
        case .info: return .blue
        }
    }

    var icon: String {
        switch self {
        case .climb: return "△"
        case .descent: return "▽"
        case .flat: return "─"
        case .aidStation: return "◉"
        case .danger: return "⚠"
        case .info: return "ℹ"
        }
    }

    var systemImage: String {
        switch self {
        case .climb: return "arrow.up.right"
        case .descent: return "arrow.down.right"
        case .flat: return "minus"
        case .aidStation: return "fork.knife"
        case .danger: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .climb: return "Climb"
        case .descent: return "Descent"
        case .flat: return "Flat"
        case .aidStation: return "Aid station"
        case .danger: return "Danger"
        case .info: return "Info"
        }
    }
}
