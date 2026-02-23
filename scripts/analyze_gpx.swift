#!/usr/bin/env swift

import Foundation

// =============================================================================
// MARK: - Models (same as app)
// =============================================================================

struct TrackPoint {
    let latitude: Double
    let longitude: Double
    let elevation: Double
    var distance: Double = 0
    let index: Int
}

struct DetectedMilestone {
    let type: String // "montee" or "descente"
    let category: String
    let elevation: Double
    let distance: Double
    let dPlus: Int
    let distanceKm: Double
    let slopePercent: Int
    let message: String
}

// =============================================================================
// MARK: - GPX Parser (same logic as app)
// =============================================================================

func parseGPX(url: URL) -> (points: [TrackPoint], dPlus: Int)? {
    guard let data = try? Data(contentsOf: url),
          let content = String(data: data, encoding: .utf8) else {
        print("❌ Erreur lecture fichier")
        return nil
    }

    var points: [TrackPoint] = []

    // Pattern pour trkpt avec ele
    let trkptPattern = #"<trkpt lat="([^"]+)" lon="([^"]+)"[^>]*>.*?<ele>([^<]+)</ele>"#
    if let regex = try? NSRegularExpression(pattern: trkptPattern, options: .dotMatchesLineSeparators) {
        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for (index, match) in matches.enumerated() {
            if let latRange = Range(match.range(at: 1), in: content),
               let lonRange = Range(match.range(at: 2), in: content),
               let eleRange = Range(match.range(at: 3), in: content),
               let lat = Double(content[latRange]),
               let lon = Double(content[lonRange]),
               let ele = Double(content[eleRange]) {
                points.append(TrackPoint(latitude: lat, longitude: lon, elevation: ele, index: index))
            }
        }
    }

    // Si pas de trkpt, essayer rtept
    if points.isEmpty {
        let rteptPattern = #"<rtept lat="([^"]+)" lon="([^"]+)"[^>]*>.*?<ele>([^<]+)</ele>"#
        if let regex = try? NSRegularExpression(pattern: rteptPattern, options: .dotMatchesLineSeparators) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

            for (index, match) in matches.enumerated() {
                if let latRange = Range(match.range(at: 1), in: content),
                   let lonRange = Range(match.range(at: 2), in: content),
                   let eleRange = Range(match.range(at: 3), in: content),
                   let lat = Double(content[latRange]),
                   let lon = Double(content[lonRange]),
                   let ele = Double(content[eleRange]) {
                    points.append(TrackPoint(latitude: lat, longitude: lon, elevation: ele, index: index))
                }
            }
        }
    }

    guard points.count >= 2 else {
        print("❌ Pas assez de points")
        return nil
    }

    // Calculate distances using Haversine
    var totalDPlus = 0.0
    var lastElevation = points[0].elevation

    for i in 0..<points.count {
        if i == 0 {
            points[i].distance = 0
        } else {
            let d = haversine(
                lat1: points[i-1].latitude, lon1: points[i-1].longitude,
                lat2: points[i].latitude, lon2: points[i].longitude
            )
            points[i].distance = points[i-1].distance + d

            // Calculate D+
            let delta = points[i].elevation - lastElevation
            if delta > 0 {
                totalDPlus += delta
            }
            lastElevation = points[i].elevation
        }
    }

    return (points, Int(totalDPlus))
}

func haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6371000.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat/2) * sin(dLat/2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon/2) * sin(dLon/2)
    let c = 2 * atan2(sqrt(a), sqrt(1-a))
    return R * c
}

// =============================================================================
// MARK: - Milestone Detector (same logic as app)
// =============================================================================

// Configuration
let minimumClimbElevation: Double = 75
let minimumDescentElevation: Double = 75
let minimumDistanceBetweenMilestones: Double = 1000
let smoothingWindow: Double = 200

enum Trend {
    case climbing
    case descending
    case flat
}

struct Segment {
    let startIndex: Int
    let endIndex: Int
    let trend: Trend
    let startDistance: Double
    let endDistance: Double
    let startElevation: Double
    let endElevation: Double

    var distance: Double { endDistance - startDistance }
    var elevationChange: Double { abs(endElevation - startElevation) }
    var averageSlope: Double {
        guard distance > 0 else { return 0 }
        return (endElevation - startElevation) / distance
    }
}

func smooth(trackPoints: [TrackPoint]) -> [Double] {
    var smoothed = [Double]()

    for point in trackPoints {
        let targetDistance = point.distance
        var sum = 0.0
        var count = 0

        for otherPoint in trackPoints {
            let distanceFromTarget = abs(otherPoint.distance - targetDistance)
            if distanceFromTarget <= smoothingWindow / 2 {
                sum += otherPoint.elevation
                count += 1
            }
        }

        smoothed.append(count > 0 ? sum / Double(count) : point.elevation)
    }

    return smoothed
}

func samplePoints(trackPoints: [TrackPoint], minDistance: Double) -> [Int] {
    guard !trackPoints.isEmpty else { return [] }

    var indices: [Int] = [0]
    var lastDistance = trackPoints[0].distance

    for i in 1..<trackPoints.count {
        if trackPoints[i].distance - lastDistance >= minDistance {
            indices.append(i)
            lastDistance = trackPoints[i].distance
        }
    }

    if indices.last != trackPoints.count - 1 {
        indices.append(trackPoints.count - 1)
    }

    return indices
}

func detectSegments(trackPoints: [TrackPoint], smoothedElevations: [Double]) -> [Segment] {
    var segments: [Segment] = []

    let sampledIndices = samplePoints(trackPoints: trackPoints, minDistance: 50)
    guard sampledIndices.count >= 2 else { return [] }

    var segmentStartIdx = 0
    var currentTrend: Trend = .flat
    var cumulativeChange: Double = 0
    var lastElevation = smoothedElevations[sampledIndices[0]]

    for i in 1..<sampledIndices.count {
        let pointIndex = sampledIndices[i]
        let currentElevation = smoothedElevations[pointIndex]
        let delta = currentElevation - lastElevation

        let deltaTrend: Trend = delta > 3 ? .climbing : (delta < -3 ? .descending : .flat)
        let trendChanged = deltaTrend != .flat && deltaTrend != currentTrend && currentTrend != .flat

        if trendChanged {
            let threshold = currentTrend == .climbing ? minimumClimbElevation : minimumDescentElevation
            if abs(cumulativeChange) >= threshold {
                let startPointIndex = sampledIndices[segmentStartIdx]
                let endPointIndex = sampledIndices[i - 1]
                let segment = Segment(
                    startIndex: startPointIndex,
                    endIndex: endPointIndex,
                    trend: currentTrend,
                    startDistance: trackPoints[startPointIndex].distance,
                    endDistance: trackPoints[endPointIndex].distance,
                    startElevation: smoothedElevations[startPointIndex],
                    endElevation: smoothedElevations[endPointIndex]
                )
                segments.append(segment)
            }

            segmentStartIdx = i - 1
            currentTrend = deltaTrend
            cumulativeChange = delta
        } else if deltaTrend != .flat {
            if currentTrend == .flat {
                currentTrend = deltaTrend
                segmentStartIdx = i - 1
            }
            cumulativeChange += delta
        }

        lastElevation = currentElevation
    }

    // Last segment
    let threshold = currentTrend == .climbing ? minimumClimbElevation : minimumDescentElevation
    if abs(cumulativeChange) >= threshold {
        let startPointIndex = sampledIndices[segmentStartIdx]
        let endPointIndex = sampledIndices[sampledIndices.count - 1]
        let segment = Segment(
            startIndex: startPointIndex,
            endIndex: endPointIndex,
            trend: currentTrend,
            startDistance: trackPoints[startPointIndex].distance,
            endDistance: trackPoints[endPointIndex].distance,
            startElevation: smoothedElevations[startPointIndex],
            endElevation: smoothedElevations[endPointIndex]
        )
        segments.append(segment)
    }

    return segments
}

func climbCategory(elevationGain: Int) -> String {
    switch elevationGain {
    case 1000...: return "HC"
    case 600..<1000: return "Cat 1"
    case 300..<600: return "Cat 2"
    case 150..<300: return "Cat 3"
    default: return "Cat 4"
    }
}

func detectMilestones(trackPoints: [TrackPoint]) -> [DetectedMilestone] {
    guard trackPoints.count >= 10 else { return [] }

    let smoothedElevations = smooth(trackPoints: trackPoints)
    let segments = detectSegments(trackPoints: trackPoints, smoothedElevations: smoothedElevations)

    var milestones: [DetectedMilestone] = []

    for segment in segments {
        guard segment.startIndex < trackPoints.count else { continue }
        let startPoint = trackPoints[segment.startIndex]

        let dPlus = Int(abs(segment.endElevation - segment.startElevation))
        let distKm = segment.distance / 1000
        let slopePercent = Int(abs(segment.averageSlope * 100))
        let category = climbCategory(elevationGain: dPlus)

        switch segment.trend {
        case .climbing:
            let message = distKm >= 1
                ? "Montée \(category) — \(dPlus) mètres sur \(String(format: "%.1f", distKm)) kilomètres, \(slopePercent)% moyen"
                : "Montée \(category) — \(dPlus) mètres sur \(Int(distKm * 1000)) mètres, \(slopePercent)% moyen"

            milestones.append(DetectedMilestone(
                type: "montee",
                category: category,
                elevation: startPoint.elevation,
                distance: startPoint.distance,
                dPlus: dPlus,
                distanceKm: distKm,
                slopePercent: slopePercent,
                message: message
            ))

        case .descending:
            let message = distKm >= 1
                ? "Descente \(category) — \(dPlus) mètres sur \(String(format: "%.1f", distKm)) kilomètres"
                : "Descente \(category) — \(dPlus) mètres sur \(Int(distKm * 1000)) mètres"

            milestones.append(DetectedMilestone(
                type: "descente",
                category: category,
                elevation: startPoint.elevation,
                distance: startPoint.distance,
                dPlus: dPlus,
                distanceKm: distKm,
                slopePercent: slopePercent,
                message: message
            ))

        case .flat:
            break
        }
    }

    // Filter by minimum distance
    var filtered: [DetectedMilestone] = []
    var lastDistance: Double = -minimumDistanceBetweenMilestones

    for milestone in milestones.sorted(by: { $0.distance < $1.distance }) {
        if milestone.distance - lastDistance >= minimumDistanceBetweenMilestones {
            filtered.append(milestone)
            lastDistance = milestone.distance
        }
    }

    return filtered
}

// =============================================================================
// MARK: - Main Analysis
// =============================================================================

struct GPXTest {
    let path: String
    let expectedDistance: Double? // km
    let expectedDPlus: Int?
}

func analyze(test: GPXTest) {
    let filename = test.path.split(separator: "/").last ?? ""
    print("\n" + String(repeating: "=", count: 60))
    print("📁 \(filename)")
    print(String(repeating: "=", count: 60))

    let url = URL(fileURLWithPath: test.path)
    guard let (points, _) = parseGPX(url: url) else {
        print("❌ Échec du parsing")
        return
    }

    let distanceKm = (points.last?.distance ?? 0) / 1000
    let elevations = points.map { $0.elevation }

    // Calculer D+ avec différentes méthodes
    let dPlusBrut = calculateDPlus(points: points, threshold: 0)
    let dPlusSeuil10 = calculateDPlus(points: points, threshold: 10)

    // Nouvelles méthodes (Option 2 + 3)
    let noise = calculateElevationNoise(points: points)
    let dPlusNoiseAdaptive = calculateNoiseAdaptiveDPlus(points: points)
    let dPlusSegment100 = calculateSegmentAverageDPlus(points: points, segmentLength: 100)
    let (dPlusFinal, finalMethod) = calculateFinalDPlus(points: points)

    // Calculer la densité
    let density = distanceKm > 0 ? Double(points.count) / distanceKm : 0

    // Basic stats
    print("\n📊 STATISTIQUES")
    print("   Points: \(points.count)")
    print("   Distance: \(String(format: "%.1f", distanceKm)) km", terminator: "")
    if let expected = test.expectedDistance {
        let diff = distanceKm - expected
        let diffPercent = (diff / expected) * 100
        let emoji = abs(diffPercent) < 5 ? "✅" : "⚠️"
        print(" \(emoji) (attendu: \(String(format: "%.1f", expected)) km, diff: \(String(format: "%+.1f", diffPercent))%)")
    } else {
        print()
    }

    print("   Altitude: \(Int(elevations.min() ?? 0))m → \(Int(elevations.max() ?? 0))m")

    // D+ comparison
    print("\n📈 CALCUL D+ (différentes méthodes)")
    if let expected = test.expectedDPlus {
        print("   Attendu:      \(expected) m")
    }

    func printDPlus(_ label: String, _ value: Int) {
        print("   \(label): \(value) m", terminator: "")
        if let expected = test.expectedDPlus {
            let diff = value - expected
            let diffPercent = Double(diff) / Double(expected) * 100
            let emoji = abs(diffPercent) < 5 ? "✅" : (abs(diffPercent) < 10 ? "🟡" : "⚠️")
            print(" \(emoji) (\(String(format: "%+.1f", diffPercent))%)")
        } else {
            print()
        }
    }

    print("   Densité: \(String(format: "%.0f", density)) pts/km | Bruit: \(String(format: "%.1f", noise))m")
    printDPlus("Brut            ", dPlusBrut)
    printDPlus("Seuil 10m       ", dPlusSeuil10)
    printDPlus("Bruit adaptatif ", dPlusNoiseAdaptive)
    printDPlus("Segments 100m   ", dPlusSegment100)
    print("   ----------------------------------------")
    printDPlus("⭐ FINAL        ", dPlusFinal)
    print("      Méthode: \(finalMethod)")

    // Milestones
    let milestones = detectMilestones(trackPoints: points)

    print("\n🎯 JALONS DÉTECTÉS: \(milestones.count)")
    for (i, m) in milestones.enumerated() {
        let emoji = m.type == "montee" ? "🔼" : "🔽"
        print("   \(i+1). \(emoji) km \(String(format: "%.1f", m.distance/1000)) - \(m.message)")
    }

    if milestones.isEmpty {
        print("   ⚠️ Aucun jalon détecté!")
    }
}

// =============================================================================
// MARK: - D+ Calculation Methods
// =============================================================================

/// Calcule le D+ avec différentes méthodes
func calculateDPlus(points: [TrackPoint], threshold: Double = 0) -> Int {
    var totalDPlus = 0.0
    var lastElevation = points[0].elevation
    var pendingGain = 0.0

    for i in 1..<points.count {
        let delta = points[i].elevation - lastElevation

        if threshold == 0 {
            // Méthode brute: somme tous les deltas positifs
            if delta > 0 {
                totalDPlus += delta
            }
            lastElevation = points[i].elevation
        } else {
            // Méthode avec seuil: ne compte que les changements > seuil
            if delta > 0 {
                pendingGain += delta
            } else if delta < 0 {
                // On descend - finaliser le gain accumulé si > seuil
                if pendingGain >= threshold {
                    totalDPlus += pendingGain
                }
                pendingGain = 0
            }
            lastElevation = points[i].elevation
        }
    }

    // Finaliser le dernier gain
    if threshold > 0 && pendingGain >= threshold {
        totalDPlus += pendingGain
    }

    return Int(totalDPlus)
}

/// Calcule le D+ sur des données lissées
func calculateSmoothedDPlus(points: [TrackPoint], windowSize: Double = 100, threshold: Double = 3) -> Int {
    guard points.count >= 2 else { return 0 }

    // 1. Lisser les élévations
    var smoothed: [Double] = []
    for point in points {
        var sum = 0.0
        var count = 0
        for other in points {
            if abs(other.distance - point.distance) <= windowSize / 2 {
                sum += other.elevation
                count += 1
            }
        }
        smoothed.append(count > 0 ? sum / Double(count) : point.elevation)
    }

    // 2. Sous-échantillonner (1 point tous les 50m)
    var sampled: [(distance: Double, elevation: Double)] = [(points[0].distance, smoothed[0])]
    var lastDist = points[0].distance
    for i in 1..<points.count {
        if points[i].distance - lastDist >= 50 {
            sampled.append((points[i].distance, smoothed[i]))
            lastDist = points[i].distance
        }
    }
    if let last = sampled.last, last.distance != points.last!.distance {
        sampled.append((points.last!.distance, smoothed.last!))
    }

    // 3. Calculer D+ avec seuil
    var totalDPlus = 0.0
    var pendingGain = 0.0
    var lastElev = sampled[0].elevation

    for i in 1..<sampled.count {
        let delta = sampled[i].elevation - lastElev
        if delta > 0 {
            pendingGain += delta
        } else if delta < -threshold {
            if pendingGain >= threshold {
                totalDPlus += pendingGain
            }
            pendingGain = 0
        }
        lastElev = sampled[i].elevation
    }
    if pendingGain >= threshold {
        totalDPlus += pendingGain
    }

    return Int(totalDPlus)
}

/// Méthode Peak/Valley - détecte les sommets et vallées significatifs
/// Inspiré des algorithmes de Strava et GPS Visualizer
func calculatePeakValleyDPlus(points: [TrackPoint], minElevationChange: Double = 10) -> Int {
    guard points.count >= 2 else { return 0 }

    // 1. Sous-échantillonner (1 point tous les 50m minimum)
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

    // 2. Lisser les élévations (moyenne mobile sur 100m)
    var smoothed: [Double] = []
    let windowSize = 100.0
    for i in 0..<sampled.count {
        var sum = 0.0
        var count = 0
        for j in 0..<sampled.count {
            if abs(sampled[j].distance - sampled[i].distance) <= windowSize / 2 {
                sum += sampled[j].elevation
                count += 1
            }
        }
        smoothed.append(count > 0 ? sum / Double(count) : sampled[i].elevation)
    }

    // 3. Détecter les pics et vallées
    var peaks: [(index: Int, elevation: Double)] = [(0, smoothed[0])]
    var isClimbing = smoothed.count > 1 && smoothed[1] > smoothed[0]

    for i in 1..<smoothed.count {
        let delta = smoothed[i] - smoothed[i - 1]

        if isClimbing && delta < -minElevationChange {
            // Était en montée, commence à descendre = pic
            peaks.append((i - 1, smoothed[i - 1]))
            isClimbing = false
        } else if !isClimbing && delta > minElevationChange {
            // Était en descente, commence à monter = vallée
            peaks.append((i - 1, smoothed[i - 1]))
            isClimbing = true
        }
    }
    peaks.append((smoothed.count - 1, smoothed[smoothed.count - 1]))

    // 4. Calculer le D+ entre les pics/vallées
    var totalDPlus = 0.0
    for i in 1..<peaks.count {
        let delta = peaks[i].elevation - peaks[i - 1].elevation
        if delta > 0 {
            totalDPlus += delta
        }
    }

    return Int(totalDPlus)
}

/// Méthode ADAPTATIVE - choisit l'algorithme selon la densité de points
func calculateAdaptiveDPlus(points: [TrackPoint]) -> Int {
    guard points.count >= 2 else { return 0 }

    let distanceKm = (points.last?.distance ?? 0) / 1000
    guard distanceKm > 0 else { return 0 }

    let density = Double(points.count) / distanceKm // points par km

    // Haute densité (>100 pts/km) : utiliser Seuil 10m
    // Basse densité (<50 pts/km) : utiliser PeakValley 5m
    // Entre les deux : moyenne pondérée

    if density > 100 {
        return calculateDPlus(points: points, threshold: 10)
    } else if density < 50 {
        return calculatePeakValleyDPlus(points: points, minElevationChange: 5)
    } else {
        // Interpolation linéaire entre 50 et 100 pts/km
        let weight = (density - 50) / 50 // 0 à 1
        let seuil = calculateDPlus(points: points, threshold: 10)
        let peak = calculatePeakValleyDPlus(points: points, minElevationChange: 5)
        return Int(Double(seuil) * weight + Double(peak) * (1 - weight))
    }
}

// =============================================================================
// MARK: - OPTION 2 : Détection automatique du bruit
// =============================================================================

/// Calcule l'écart-type des variations d'élévation entre points consécutifs
func calculateElevationNoise(points: [TrackPoint]) -> Double {
    guard points.count >= 3 else { return 0 }

    var deltas: [Double] = []
    for i in 1..<points.count {
        let delta = points[i].elevation - points[i-1].elevation
        deltas.append(delta)
    }

    let mean = deltas.reduce(0, +) / Double(deltas.count)
    let variance = deltas.map { pow($0 - mean, 2) }.reduce(0, +) / Double(deltas.count)
    return sqrt(variance) // écart-type
}

/// Méthode avec seuil adaptatif basé sur le bruit détecté
func calculateNoiseAdaptiveDPlus(points: [TrackPoint]) -> Int {
    guard points.count >= 2 else { return 0 }

    let noise = calculateElevationNoise(points: points)

    // Adapter le seuil en fonction du bruit
    // Bruit faible (<3m) → seuil 3m (données barométriques probables)
    // Bruit moyen (3-8m) → seuil proportionnel
    // Bruit élevé (>8m) → seuil 15m (GPS bruité)
    let threshold: Double
    if noise < 3 {
        threshold = 3
    } else if noise > 8 {
        threshold = 15
    } else {
        threshold = noise * 1.5 // seuil = 1.5x le bruit
    }

    return calculateDPlus(points: points, threshold: threshold)
}

// =============================================================================
// MARK: - OPTION 3 : Analyse par segments fixes
// =============================================================================

/// Découpe la trace en segments de X mètres et calcule le D+ sur les min/max de chaque segment
func calculateSegmentDPlus(points: [TrackPoint], segmentLength: Double = 100) -> Int {
    guard points.count >= 2 else { return 0 }

    let totalDistance = points.last?.distance ?? 0
    guard totalDistance > 0 else { return 0 }

    // Découper en segments
    var segments: [(minElev: Double, maxElev: Double)] = []
    var currentSegmentStart = 0.0
    var currentMin = points[0].elevation
    var currentMax = points[0].elevation

    for point in points {
        if point.distance - currentSegmentStart >= segmentLength {
            // Finaliser le segment actuel
            segments.append((minElev: currentMin, maxElev: currentMax))
            // Commencer un nouveau segment
            currentSegmentStart = point.distance
            currentMin = point.elevation
            currentMax = point.elevation
        } else {
            currentMin = min(currentMin, point.elevation)
            currentMax = max(currentMax, point.elevation)
        }
    }
    // Ajouter le dernier segment
    segments.append((minElev: currentMin, maxElev: currentMax))

    guard segments.count >= 2 else { return 0 }

    // Extraire les points clés (alternance min/max pour chaque segment)
    var keyPoints: [Double] = []
    var lastWasMax = false

    for (i, segment) in segments.enumerated() {
        if i == 0 {
            // Premier segment : commencer par le point de départ
            keyPoints.append(points[0].elevation)
            lastWasMax = points[0].elevation == segment.maxElev
        }

        // Ajouter min et max du segment dans le bon ordre
        if lastWasMax {
            if segment.minElev != keyPoints.last {
                keyPoints.append(segment.minElev)
            }
            if segment.maxElev != keyPoints.last {
                keyPoints.append(segment.maxElev)
                lastWasMax = true
            } else {
                lastWasMax = false
            }
        } else {
            if segment.maxElev != keyPoints.last {
                keyPoints.append(segment.maxElev)
            }
            if segment.minElev != keyPoints.last {
                keyPoints.append(segment.minElev)
                lastWasMax = false
            } else {
                lastWasMax = true
            }
        }
    }

    // Calculer D+ sur les points clés
    var totalDPlus = 0.0
    for i in 1..<keyPoints.count {
        let delta = keyPoints[i] - keyPoints[i-1]
        if delta > 0 {
            totalDPlus += delta
        }
    }

    return Int(totalDPlus)
}

/// Version simplifiée : élévation moyenne par segment de 100m - O(n)
func calculateSegmentAverageDPlus(points: [TrackPoint], segmentLength: Double = 100) -> Int {
    guard points.count >= 2 else { return 0 }

    let totalDistance = points.last?.distance ?? 0
    guard totalDistance > 0 else { return 0 }

    // Calculer l'élévation moyenne par segment - O(n)
    var segmentElevations: [Double] = []
    var currentSegmentStart = 0.0
    var elevationSum = 0.0
    var pointCount = 0

    for point in points {
        if point.distance - currentSegmentStart >= segmentLength && pointCount > 0 {
            segmentElevations.append(elevationSum / Double(pointCount))
            currentSegmentStart = point.distance
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

    // Calculer D+ avec seuil sur les segments
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

// =============================================================================
// MARK: - OPTION 2+3 COMBINÉE
// =============================================================================

/// Méthode combinée : segments + adaptation au bruit
func calculateOptimizedDPlus(points: [TrackPoint]) -> Int {
    guard points.count >= 2 else { return 0 }

    let noise = calculateElevationNoise(points: points)
    let distanceKm = (points.last?.distance ?? 0) / 1000
    let density = distanceKm > 0 ? Double(points.count) / distanceKm : 0

    // Adapter la taille des segments au bruit et à la densité
    let segmentLength: Double
    let threshold: Double

    if noise < 3 {
        // Données de qualité (probablement barométrique)
        segmentLength = 50
        threshold = 3
    } else if noise < 6 {
        // Bruit modéré
        segmentLength = 75
        threshold = 5
    } else {
        // Bruit élevé (GPS)
        segmentLength = 100
        threshold = 8
    }

    // Calculer l'élévation moyenne par segment
    var segmentElevations: [Double] = []
    var currentSegmentStart = 0.0
    var elevationSum = 0.0
    var pointCount = 0

    for point in points {
        if point.distance - currentSegmentStart >= segmentLength && pointCount > 0 {
            segmentElevations.append(elevationSum / Double(pointCount))
            currentSegmentStart = point.distance
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

    // Calculer D+ avec seuil adapté
    var totalDPlus = 0.0
    var pendingGain = 0.0

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

/// MÉTHODE FINALE V2 : Combinaison intelligente basée sur les caractéristiques du fichier
func calculateFinalDPlus(points: [TrackPoint]) -> (dPlus: Int, method: String) {
    guard points.count >= 2 else { return (0, "N/A") }

    let noise = calculateElevationNoise(points: points)
    let distanceKm = (points.last?.distance ?? 0) / 1000
    let density = distanceKm > 0 ? Double(points.count) / distanceKm : 0

    // Calculer avec plusieurs méthodes
    let segment100 = calculateSegmentAverageDPlus(points: points, segmentLength: 100)
    let seuil10 = calculateDPlus(points: points, threshold: 10)
    let noiseAdaptive = calculateNoiseAdaptiveDPlus(points: points)
    let peakValley5 = calculatePeakValleyDPlus(points: points, minElevationChange: 5)

    // Choisir la méthode selon les caractéristiques
    if noise > 6 {
        // Bruit élevé → Bruit adaptatif
        return (noiseAdaptive, "Bruit adaptatif (noise=\(String(format: "%.1f", noise)))")
    } else if density > 80 {
        // Haute densité, faible bruit → Segments 100m
        return (segment100, "Segments 100m (density=\(Int(density)))")
    } else if density < 50 && noise > 2 {
        // Basse densité + bruit modéré → PeakValley 5m
        return (peakValley5, "PeakValley 5m (density=\(Int(density)), noise=\(String(format: "%.1f", noise)))")
    } else {
        // Autres cas → Seuil 10m
        return (seuil10, "Seuil 10m (density=\(Int(density)))")
    }
}

/// Méthode combinée : Peak/Valley avec seuil minimum de gain
func calculateCombinedDPlus(points: [TrackPoint], minGain: Double = 5) -> Int {
    guard points.count >= 2 else { return 0 }

    // 1. Sous-échantillonner (1 point tous les 30m pour plus de précision)
    var sampled: [(distance: Double, elevation: Double)] = [(points[0].distance, points[0].elevation)]
    var lastDist = points[0].distance
    for point in points {
        if point.distance - lastDist >= 30 {
            sampled.append((point.distance, point.elevation))
            lastDist = point.distance
        }
    }
    if let last = points.last, sampled.last?.distance != last.distance {
        sampled.append((last.distance, last.elevation))
    }

    guard sampled.count >= 2 else { return 0 }

    // 2. Lisser les élévations (moyenne mobile sur 50m - plus réactif)
    var smoothed: [Double] = []
    let windowSize = 50.0
    for i in 0..<sampled.count {
        var sum = 0.0
        var count = 0
        for j in 0..<sampled.count {
            if abs(sampled[j].distance - sampled[i].distance) <= windowSize / 2 {
                sum += sampled[j].elevation
                count += 1
            }
        }
        smoothed.append(count > 0 ? sum / Double(count) : sampled[i].elevation)
    }

    // 3. Accumuler le D+ avec seuil de validation
    var totalDPlus = 0.0
    var pendingGain = 0.0
    var lastElev = smoothed[0]
    var lastPeakElev = smoothed[0]

    for i in 1..<smoothed.count {
        let delta = smoothed[i] - lastElev

        if delta > 0 {
            pendingGain += delta
        } else if delta < -minGain && pendingGain > 0 {
            // On descend significativement - valider le gain accumulé
            if pendingGain >= minGain {
                totalDPlus += pendingGain
            }
            pendingGain = 0
            lastPeakElev = smoothed[i - 1]
        }
        lastElev = smoothed[i]
    }

    // Finaliser le dernier gain
    if pendingGain >= minGain {
        totalDPlus += pendingGain
    }

    return Int(totalDPlus)
}

// =============================================================================
// MARK: - Run Tests
// =============================================================================

print("🏔️ TrailMark GPX Analyzer")
print("   Paramètres: D+ min=\(Int(minimumClimbElevation))m, D- min=\(Int(minimumDescentElevation))m, dist min=\(Int(minimumDistanceBetweenMilestones))m")

// GPX test folder with files named: name-distance+dplus-dminus.gpx
let gpxTestFolder = "/Users/nicolasbarbosa/Library/Mobile Documents/com~apple~CloudDocs/Documents/gpx-test"

// Parse filename to extract expected values
func parseFilename(_ filename: String) -> (name: String, distance: Double?, dPlus: Int?, dMinus: Int?)? {
    // Format: name-distance+dplus-dminus or name-distance+dplus-dminus.gpx
    let name = filename.replacingOccurrences(of: ".gpx", with: "")

    // Try to parse: name-XXX+YYY-ZZZ
    let parts = name.components(separatedBy: "-")
    guard parts.count >= 2 else { return (name, nil, nil, nil) }

    // Find the part with + (distance+dplus)
    for i in 0..<parts.count {
        if parts[i].contains("+") {
            let distPlusParts = parts[i].components(separatedBy: "+")
            if distPlusParts.count == 2,
               let dist = Double(distPlusParts[0]),
               let dPlus = Int(distPlusParts[1]) {
                // Next part should be dMinus
                let dMinus = i + 1 < parts.count ? Int(parts[i + 1]) : nil
                let baseName = parts[0..<i].joined(separator: "-")
                return (baseName, dist, dPlus, dMinus)
            }
        }
    }
    return (name, nil, nil, nil)
}

// List all files in test folder
let fileManager = FileManager.default
if let files = try? fileManager.contentsOfDirectory(atPath: gpxTestFolder) {
    // Include files with .gpx extension OR files without any extension (assuming they're GPX)
    let gpxFiles = files.filter { !$0.hasPrefix(".") && ($0.hasSuffix(".gpx") || !$0.contains(".")) }

    for file in gpxFiles.sorted() {
        let path = "\(gpxTestFolder)/\(file)"
        guard fileManager.fileExists(atPath: path) else { continue }

        let parsed = parseFilename(file)
        let test = GPXTest(
            path: path,
            expectedDistance: parsed?.distance,
            expectedDPlus: parsed?.dPlus
        )
        analyze(test: test)
    }
} else {
    print("❌ Impossible de lire le dossier: \(gpxTestFolder)")
}

print("\n" + String(repeating: "=", count: 60))
print("✅ Analyse terminée")
