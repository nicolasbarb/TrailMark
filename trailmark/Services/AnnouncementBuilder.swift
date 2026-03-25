import Foundation

/// Builds localized, human-readable announcement strings for milestones.
/// Used both for auto-detection (import) and manual milestone creation (editor).
/// The same text is displayed in the UI and read aloud by the TTS.
enum AnnouncementBuilder {

    /// Builds a readable announcement from terrain stats.
    /// - Parameters:
    ///   - type: The milestone type (only climb/descent/flat produce a message)
    ///   - distance: Segment distance in meters
    ///   - elevation: Elevation gain (climb) or loss (descent) in meters
    ///   - slope: Average slope as a ratio (e.g., 0.12 for 12%)
    /// - Returns: A localized string, or nil if the type doesn't support auto-messages
    static func build(
        type: MilestoneType,
        distance: Double,
        elevation: Double,
        slope: Double
    ) -> String? {
        let distStr = formatDistance(distance)
        let slopePercent = Int((abs(slope) * 100).rounded())
        let elev = Int(elevation)

        switch type {
        case .climb:
            return String(localized: "tts.climb \(distStr) \(slopePercent) \(elev)")
        case .descent:
            return String(localized: "tts.descent \(distStr) \(slopePercent) \(elev)")
        case .flat:
            return String(localized: "tts.flat \(distStr)")
        default:
            return nil
        }
    }

    // MARK: - Distance Formatting

    /// Formats distance for display: "800 m" or "1.8 km" (locale-aware decimal)
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        }

        let km = meters / 1000
        let rounded = (km * 10).rounded() / 10

        if rounded == rounded.rounded() {
            return "\(Int(rounded)) km"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let formattedKm = formatter.string(from: NSNumber(value: rounded)) ?? String(format: "%.1f", rounded)
        return "\(formattedKm) km"
    }
}
