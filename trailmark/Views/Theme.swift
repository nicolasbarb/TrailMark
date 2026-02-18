import SwiftUI

// MARK: - Trail Colors

/// Predefined trail colors using native Apple colors
enum TrailColor: String, CaseIterable, Sendable {
    case orange
    case green
    case blue
    case purple
    case cyan
    case pink
    case red
    case yellow

    nonisolated var color: Color {
        switch self {
        case .orange: return .orange
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .cyan: return .cyan
        case .pink: return .pink
        case .red: return .red
        case .yellow: return .yellow
        }
    }

    nonisolated static var `default`: TrailColor { .orange }
}

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
    static let accent = Color.orange
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
        case .montee: return .orange
        case .descente: return .cyan
        case .plat: return .green
        case .ravito: return .purple
        case .danger: return .red
        case .info: return .blue
        }
    }

    var icon: String {
        switch self {
        case .montee: return "△"
        case .descente: return "▽"
        case .plat: return "─"
        case .ravito: return "◉"
        case .danger: return "⚠"
        case .info: return "ℹ"
        }
    }

    var label: String {
        switch self {
        case .montee: return "Montée"
        case .descente: return "Descente"
        case .plat: return "Plat"
        case .ravito: return "Ravito"
        case .danger: return "Danger"
        case .info: return "Info"
        }
    }
}
