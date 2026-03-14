import Foundation

/// Builds TTS-formatted French announcement strings from milestone data
enum AnnouncementBuilder {

    /// Builds an enriched announcement for a milestone
    /// - Parameters:
    ///   - type: The milestone type
    ///   - name: Optional name (e.g., "Col de la Croix")
    ///   - lookaheadStats: Terrain zone stats from the milestone forward
    /// - Returns: A TTS-ready French string, or nil if type is not montee/descente or stats are nil
    static func build(
        type: MilestoneType,
        name: String?,
        lookaheadStats: ElevationProfileAnalyzer.LookaheadStats?
    ) -> String? {
        guard type == .montee || type == .descente else { return nil }
        guard let stats = lookaheadStats else { return nil }

        var parts: [String] = []

        // Type label + optional name
        if let name, !name.isEmpty {
            parts.append("\(type.label), \(name)")
        } else {
            parts.append(type.label)
        }

        // Segment distance + slope
        let distanceStr = formatDistance(stats.distance)
        let slopePercent = Int((abs(stats.averageSlope) * 100).rounded())
        parts.append("\(distanceStr) à \(slopePercent) pourcent")

        // Elevation gain/loss
        switch type {
        case .montee:
            let dPlus = Int(stats.elevationGain)
            parts.append("\(dPlus) mètres de dénivelé positif")
        case .descente:
            let dMinus = Int(stats.elevationLoss)
            parts.append("\(dMinus) mètres de dénivelé négatif")
        default:
            break
        }

        return parts.joined(separator: ". ") + "."
    }

    // MARK: - TTS Formatting

    /// Formats distance for French TTS reading
    /// - < 1000m: "800 mètres"
    /// - >= 1000m, whole km: "3 kilomètres"
    /// - >= 1000m, decimal: "1 virgule 8 kilomètres"
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) mètres"
        }

        let km = meters / 1000
        let rounded = (km * 10).rounded() / 10

        if rounded == rounded.rounded() {
            return "\(Int(rounded)) kilomètres"
        }

        let wholePart = Int(rounded)
        let decimalPart = Int((rounded - Double(wholePart)) * 10)
        return "\(wholePart) virgule \(decimalPart) kilomètres"
    }
}
