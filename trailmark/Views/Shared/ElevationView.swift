import SwiftUI

enum ElevationType {
    case dPlus      // Dénivelé positif cumulé (D+)
    case altitude   // Altitude à un point (ALT)
}

struct ElevationView: View {
    let value: String
    let type: ElevationType

    init(meters: Double, type: ElevationType = .altitude) {
        self.value = "\(Int(meters))"
        self.type = type
    }

    init(meters: Int, type: ElevationType = .dPlus) {
        self.value = "\(meters)"
        self.type = type
    }

    private var label: String {
        switch type {
        case .dPlus: return "D+"
        case .altitude: return "m"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(TM.textSecondary)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(TM.textTertiary)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ElevationView(meters: 450, type: .dPlus)
        ElevationView(meters: 2350.0, type: .altitude)
    }
    .padding()
}
