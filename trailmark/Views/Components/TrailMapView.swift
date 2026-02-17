import SwiftUI
import MapKit

struct TrailMapView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    let cursorPointIndex: Int?
    let trailColor: String

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            // Trace glow
            MapPolyline(coordinates: coordinates)
                .stroke(TM.trace.opacity(0.2), lineWidth: 10)

            // Trace line
            MapPolyline(coordinates: coordinates)
                .stroke(TM.trace, lineWidth: 3.5)

            // Start marker
            if let first = trackPoints.first {
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                    Circle()
                        .fill(TM.success)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
            }

            // End marker
            if let last = trackPoints.last, trackPoints.count > 1 {
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                    Circle()
                        .fill(TM.danger)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
            }

            // Milestone markers
            ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: milestone.latitude, longitude: milestone.longitude)) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(milestone.milestoneType.color, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                }
            }

            // Cursor (synced with elevation profile)
            if let index = cursorPointIndex, index < trackPoints.count {
                let point = trackPoints[index]
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) {
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(TM.trace, lineWidth: 2)
                        )
                        .shadow(color: TM.trace.opacity(0.5), radius: 8)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            updateCameraPosition()
        }
    }

    private var coordinates: [CLLocationCoordinate2D] {
        trackPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private func updateCameraPosition() {
        guard !trackPoints.isEmpty else { return }

        let minLat = trackPoints.map(\.latitude).min() ?? 0
        let maxLat = trackPoints.map(\.latitude).max() ?? 0
        let minLon = trackPoints.map(\.longitude).min() ?? 0
        let maxLon = trackPoints.map(\.longitude).max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latDelta = (maxLat - minLat) * 1.3
        let lonDelta = (maxLon - minLon) * 1.3

        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.01),
            longitudeDelta: max(lonDelta, 0.01)
        )

        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}

#Preview {
    TrailMapView(
        trackPoints: [
            TrackPoint(id: 1, trailId: 1, index: 0, latitude: 45.8, longitude: 6.8, elevation: 1000, distance: 0),
            TrackPoint(id: 2, trailId: 1, index: 1, latitude: 45.81, longitude: 6.81, elevation: 1100, distance: 1000),
            TrackPoint(id: 3, trailId: 1, index: 2, latitude: 45.82, longitude: 6.82, elevation: 1200, distance: 2000)
        ],
        milestones: [],
        cursorPointIndex: nil,
        trailColor: "f97316"
    )
    .preferredColorScheme(.dark)
}
