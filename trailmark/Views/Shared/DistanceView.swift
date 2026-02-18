import SwiftUI

struct DistanceView: View {
    let kilometers: String

    init(meters: Double) {
        self.kilometers = String(format: "%.1f", meters / 1000)
    }

    init(kilometers: String) {
        self.kilometers = kilometers
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(kilometers)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(TM.textSecondary)
            Text("KM")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(TM.textTertiary)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DistanceView(meters: 15000)
        DistanceView(kilometers: "42.2")
    }
    .padding()
}
