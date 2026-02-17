import SwiftUI

// MARK: - Design System

enum TM {
    // MARK: Backgrounds
    static let bgPrimary = Color(hex: "1a1d23")
    static let bgSecondary = Color(hex: "22262e")
    static let bgTertiary = Color(hex: "2a2f38")
    static let bgCard = Color(hex: "272b34")

    // MARK: Text
    static let textPrimary = Color(hex: "e8eaed")
    static let textSecondary = Color(hex: "9aa0ab")
    static let textMuted = Color(hex: "6b7280")

    // MARK: Accents
    static let accent = Color(hex: "f97316")
    static let accentDark = Color(hex: "ea580c")
    static let trace = Color(hex: "38bdf8")
    static let traceGlow = Color(hex: "38bdf8").opacity(0.3)
    static let border = Color(hex: "353a45")
    static let danger = Color(hex: "ef4444")
    static let success = Color(hex: "22c55e")

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
        case .montee: return Color(hex: "f97316")
        case .descente: return Color(hex: "38bdf8")
        case .plat: return Color(hex: "a3e635")
        case .ravito: return Color(hex: "c084fc")
        case .danger: return Color(hex: "ef4444")
        case .info: return Color(hex: "60a5fa")
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

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
