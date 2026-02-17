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

        // Calculate cumulative distances and D+
        var points: [ParsedPoint] = []
        var cumulativeDistance: Double = 0
        var dPlus: Int = 0
        var previousLocation: CLLocation?
        var previousElevation: Double?

        for raw in delegate.rawPoints {
            let location = CLLocation(latitude: raw.latitude, longitude: raw.longitude)

            if let prev = previousLocation {
                cumulativeDistance += location.distance(from: prev)
            }

            if let prevEle = previousElevation {
                let delta = raw.elevation - prevEle
                if delta > 0 {
                    dPlus += Int(delta)
                }
            }

            points.append(ParsedPoint(
                latitude: raw.latitude,
                longitude: raw.longitude,
                elevation: raw.elevation,
                distance: cumulativeDistance
            ))

            previousLocation = location
            previousElevation = raw.elevation
        }

        return (points, dPlus)
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
