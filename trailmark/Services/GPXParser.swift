import Foundation
import CoreLocation

// MARK: - ParsedPoint

struct ParsedPoint: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let elevation: Double
    let distance: Double // cumulative distance from start

    nonisolated init(latitude: Double, longitude: Double, elevation: Double, distance: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.distance = distance
    }
}

// MARK: - GPXParser

struct GPXParser: Sendable {
    enum ParseError: Error, LocalizedError, Sendable {
        case fileNotFound
        case invalidFormat
        case notEnoughPoints

        nonisolated var errorDescription: String? {
            switch self {
            case .fileNotFound: return "Fichier introuvable"
            case .invalidFormat: return "Format GPX invalide"
            case .notEnoughPoints: return "Le fichier doit contenir au moins 2 points"
            }
        }
    }

    @MainActor static func parse(url: URL) throws -> (points: [ParsedPoint], dPlus: Int) {
        guard url.startAccessingSecurityScopedResource() else {
            throw ParseError.fileNotFound
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let delegate = GPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw ParseError.invalidFormat
        }

        guard delegate.rawPoints.count >= 2 else {
            throw ParseError.notEnoughPoints
        }

        // Calculate cumulative distances
        var points: [ParsedPoint] = []
        var cumulativeDistance: Double = 0
        var previousLocation: CLLocation?

        for raw in delegate.rawPoints {
            let location = CLLocation(latitude: raw.latitude, longitude: raw.longitude)

            if let prev = previousLocation {
                cumulativeDistance += location.distance(from: prev)
            }

            points.append(ParsedPoint(
                latitude: raw.latitude,
                longitude: raw.longitude,
                elevation: raw.elevation,
                distance: cumulativeDistance
            ))

            previousLocation = location
        }

        // Calculate D+ with adaptive method (auto-selects best algorithm)
        let dPlus = calculateAdaptiveDPlus(points: points)

        return (points, dPlus)
    }

    // MARK: - D+ Calculation (Adaptive Algorithm)

    /// Calcule le D+ avec sélection automatique de la meilleure méthode
    /// basée sur la densité de points et le niveau de bruit
    private static func calculateAdaptiveDPlus(points: [ParsedPoint]) -> Int {
        guard points.count >= 2 else { return 0 }

        let distanceKm = (points.last?.distance ?? 0) / 1000
        guard distanceKm > 0 else { return 0 }

        let noise = calculateElevationNoise(points: points)
        let density = Double(points.count) / distanceKm

        // Sélection automatique de la méthode
        if noise > 6 {
            // Bruit élevé (GPS) → seuil adapté au bruit
            let threshold = min(15, noise * 1.5)
            return calculateDPlusWithThreshold(points: points, threshold: threshold)
        } else if density > 80 {
            // Haute densité, faible bruit → Segments 100m
            return calculateSegmentDPlus(points: points, segmentLength: 100)
        } else if density < 50 && noise > 2 {
            // Basse densité + bruit modéré → PeakValley
            return calculatePeakValleyDPlus(points: points, minChange: 5)
        } else {
            // Autres cas → Seuil 10m
            return calculateDPlusWithThreshold(points: points, threshold: 10)
        }
    }

    /// Calcule l'écart-type des variations d'élévation (niveau de bruit)
    private static func calculateElevationNoise(points: [ParsedPoint]) -> Double {
        guard points.count >= 3 else { return 0 }

        var deltas: [Double] = []
        for i in 1..<points.count {
            deltas.append(points[i].elevation - points[i-1].elevation)
        }

        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.map { pow($0 - mean, 2) }.reduce(0, +) / Double(deltas.count)
        return sqrt(variance)
    }

    /// Méthode Seuil : compte les gains cumulés > seuil
    private static func calculateDPlusWithThreshold(points: [ParsedPoint], threshold: Double) -> Int {
        guard points.count >= 2 else { return 0 }

        var totalDPlus = 0.0
        var pendingGain = 0.0
        var lastElevation = points[0].elevation

        for i in 1..<points.count {
            let delta = points[i].elevation - lastElevation
            if delta > 0 {
                pendingGain += delta
            } else if delta < 0 {
                if pendingGain >= threshold {
                    totalDPlus += pendingGain
                }
                pendingGain = 0
            }
            lastElevation = points[i].elevation
        }

        if pendingGain >= threshold {
            totalDPlus += pendingGain
        }

        return Int(totalDPlus)
    }

    /// Méthode Segments : élévation moyenne par segment de X mètres
    private static func calculateSegmentDPlus(points: [ParsedPoint], segmentLength: Double) -> Int {
        guard points.count >= 2 else { return 0 }

        // Calculer l'élévation moyenne par segment
        var segmentElevations: [Double] = []
        var segmentStart = 0.0
        var elevationSum = 0.0
        var pointCount = 0

        for point in points {
            if point.distance - segmentStart >= segmentLength && pointCount > 0 {
                segmentElevations.append(elevationSum / Double(pointCount))
                segmentStart = point.distance
                elevationSum = point.elevation
                pointCount = 1
            } else {
                elevationSum += point.elevation
                pointCount += 1
            }
        }
        if pointCount > 0 {
            segmentElevations.append(elevationSum / Double(pointCount))
        }

        // Calculer D+ avec seuil de 5m entre segments
        var totalDPlus = 0.0
        var pendingGain = 0.0
        let threshold = 5.0

        for i in 1..<segmentElevations.count {
            let delta = segmentElevations[i] - segmentElevations[i-1]
            if delta > 0 {
                pendingGain += delta
            } else if delta < -threshold {
                if pendingGain >= threshold {
                    totalDPlus += pendingGain
                }
                pendingGain = 0
            }
        }
        if pendingGain >= threshold {
            totalDPlus += pendingGain
        }

        return Int(totalDPlus)
    }

    /// Méthode PeakValley : détection des sommets et vallées
    private static func calculatePeakValleyDPlus(points: [ParsedPoint], minChange: Double) -> Int {
        guard points.count >= 2 else { return 0 }

        // Sous-échantillonner (1 point tous les 50m)
        var sampled: [(distance: Double, elevation: Double)] = [(points[0].distance, points[0].elevation)]
        var lastDist = points[0].distance
        for point in points {
            if point.distance - lastDist >= 50 {
                sampled.append((point.distance, point.elevation))
                lastDist = point.distance
            }
        }
        if let last = points.last, sampled.last?.distance != last.distance {
            sampled.append((last.distance, last.elevation))
        }

        guard sampled.count >= 2 else { return 0 }

        // Lissage par segments de 100m (O(n) au lieu de O(n²))
        var smoothed: [Double] = []
        var segmentStart = 0
        var sum = 0.0
        var count = 0

        for i in 0..<sampled.count {
            sum += sampled[i].elevation
            count += 1

            // Nouveau segment tous les 100m ou à la fin
            let isNewSegment = i == sampled.count - 1 ||
                (i + 1 < sampled.count && sampled[i + 1].distance - sampled[segmentStart].distance >= 100)

            if isNewSegment && count > 0 {
                let avg = sum / Double(count)
                for _ in segmentStart...i {
                    smoothed.append(avg)
                }
                segmentStart = i + 1
                sum = 0
                count = 0
            }
        }

        // Détecter les pics et vallées
        var peaks: [(index: Int, elevation: Double)] = [(0, smoothed[0])]
        var isClimbing = smoothed.count > 1 && smoothed[1] > smoothed[0]

        for i in 1..<smoothed.count {
            let delta = smoothed[i] - smoothed[i - 1]
            if isClimbing && delta < -minChange {
                peaks.append((i - 1, smoothed[i - 1]))
                isClimbing = false
            } else if !isClimbing && delta > minChange {
                peaks.append((i - 1, smoothed[i - 1]))
                isClimbing = true
            }
        }
        peaks.append((smoothed.count - 1, smoothed[smoothed.count - 1]))

        // Calculer D+ entre pics/vallées
        var totalDPlus = 0.0
        for i in 1..<peaks.count {
            let delta = peaks[i].elevation - peaks[i - 1].elevation
            if delta > 0 {
                totalDPlus += delta
            }
        }

        return Int(totalDPlus)
    }

    nonisolated static func trailName(from url: URL) -> String {
        let filename = url.deletingPathExtension().lastPathComponent
        return filename
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

// MARK: - GPXParserDelegate

@MainActor
private class GPXParserDelegate: NSObject, XMLParserDelegate {
    struct RawPoint {
        let latitude: Double
        let longitude: Double
        let elevation: Double
    }

    var rawPoints: [RawPoint] = []
    private var currentElement: String = ""
    private var currentLatitude: Double?
    private var currentLongitude: Double?
    private var currentElevation: String = ""
    private var isInTrackPoint = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        // Handle both <trkpt> and <rtept> elements
        if elementName == "trkpt" || elementName == "rtept" {
            isInTrackPoint = true
            currentLatitude = Double(attributeDict["lat"] ?? "")
            currentLongitude = Double(attributeDict["lon"] ?? "")
            currentElevation = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInTrackPoint && currentElement == "ele" {
            currentElevation += string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if (elementName == "trkpt" || elementName == "rtept") && isInTrackPoint {
            if let lat = currentLatitude,
               let lon = currentLongitude {
                let elevation = Double(currentElevation) ?? 0
                rawPoints.append(RawPoint(latitude: lat, longitude: lon, elevation: elevation))
            }
            isInTrackPoint = false
            currentLatitude = nil
            currentLongitude = nil
            currentElevation = ""
        }
        currentElement = ""
    }
}
