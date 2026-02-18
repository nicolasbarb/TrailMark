import SwiftUI

struct PointStatsView: View {
    let distanceMeters: Double
    let altitudeMeters: Double

    var body: some View {
        HStack(spacing: 4) {
            DistanceView(meters: distanceMeters)
            Text("·")
                .foregroundStyle(TM.textMuted)
            ElevationView(meters: altitudeMeters, type: .altitude)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PointStatsView(distanceMeters: 3500, altitudeMeters: 2350)
        PointStatsView(distanceMeters: 12800, altitudeMeters: 1850)
    }
    .padding()
}
