import SwiftUI

struct TrailStatsView: View {
    let distanceKm: String
    let dPlus: Int

    init(distanceMeters: Double, dPlus: Int) {
        self.distanceKm = String(format: "%.1f", distanceMeters / 1000)
        self.dPlus = dPlus
    }

    init(distanceKm: String, dPlus: Int) {
        self.distanceKm = distanceKm
        self.dPlus = dPlus
    }

    var body: some View {
        HStack(spacing: 4) {
            DistanceView(kilometers: distanceKm)
            Text("·")
                .foregroundStyle(TM.textMuted)
            ElevationView(meters: dPlus, type: .dPlus)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TrailStatsView(distanceKm: "15.2", dPlus: 450)
        TrailStatsView(distanceMeters: 42195, dPlus: 1200)
    }
    .padding()
}
