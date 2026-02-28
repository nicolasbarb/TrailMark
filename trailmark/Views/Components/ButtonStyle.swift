import SwiftUI

// MARK: - Test View

// MARK: - Role Wrapper (for Picker compatibility)

enum ButtonRoleOption: String, CaseIterable {
    case none = "None"
    case destructive = "Destructive"
    case cancel = "Cancel"

    var role: ButtonRole? {
        switch self {
        case .none: nil
        case .destructive: .destructive
        case .cancel: .cancel
        }
    }
}

// MARK: - Shape Wrapper (for Picker compatibility)

enum ButtonShapeOption: String, CaseIterable {
    case automatic = "Auto"
    case capsule = "Capsule"
    case roundedRectangle = "Rounded"
    case circle = "Circle"

    var shape: ButtonBorderShape {
        switch self {
        case .automatic: .automatic
        case .capsule: .capsule
        case .roundedRectangle: .roundedRectangle(radius: 12)
        case .circle: .circle
        }
    }
}

// MARK: - Test View

struct ButtonTestView: View {
    @State private var selectedSize: ControlSize = .regular
    @State private var selectedRole: ButtonRoleOption = .none
    @State private var selectedShape: ButtonShapeOption = .automatic

    // Helper to create button with dynamic role
    private func makeButton(_ title: String) -> some View {
        Button(title, role: selectedRole.role) { }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Pickers

            VStack(spacing: 12) {
                // Control Size
                VStack(spacing: 4) {
                    Text("Control Size")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Control Size", selection: $selectedSize) {
                        Text("Mini").tag(ControlSize.mini)
                        Text("Small").tag(ControlSize.small)
                        Text("Regular").tag(ControlSize.regular)
                        Text("Large").tag(ControlSize.large)
                    }
                    .pickerStyle(.segmented)
                }

                // Button Role
                VStack(spacing: 4) {
                    Text("Button Role")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Button Role", selection: $selectedRole) {
                        ForEach(ButtonRoleOption.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Button Border Shape
                VStack(spacing: 4) {
                    Text("Button Border Shape")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Button Border Shape", selection: $selectedShape) {
                        ForEach(ButtonShapeOption.allCases, id: \.self) { shape in
                            Text(shape.rawValue).tag(shape)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding()
            .background(TM.bgSecondary)

            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Classic Styles (iOS 15+)

                    Text("Classic Styles (iOS 15+)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    makeButton("Par défaut - .automatic")
                        .buttonStyle(.automatic)

                    makeButton("Discret - .plain")
                        .buttonStyle(.plain)

                    makeButton("Secondaire - .borderless")
                        .buttonStyle(.borderless)

                    makeButton("Alternative - .bordered")
                        .buttonStyle(.bordered)
                        // .tint(.gray)

                    makeButton("Principale - .borderedProminent")
                        .buttonStyle(.borderedProminent)
                        // .tint(.orange)

                    Divider()
                        .padding(.vertical, 8)

                    // MARK: - Glass Styles (iOS 26+)

                    Text("Glass Styles (iOS 26+)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    makeButton("Secondaire - .glass")
                        .buttonStyle(.glass)

                    makeButton("Principale - .glassProminent")
                        .buttonStyle(.glassProminent)
                        .buttonSizing(.flexible)
                }
                .padding()
                .controlSize(selectedSize)
                .buttonBorderShape(selectedShape.shape)
            }
        }
    }
}

#Preview {
    ButtonTestView()
        .preferredColorScheme(.dark)
}

// MARK: - View Modifiers

extension View {
    
    func primaryButton(size: ControlSize = .large, width: ButtonSizing = .automatic, shape: ButtonBorderShape = .capsule) -> some View {
        self
            .buttonStyle(.glassProminent)
            .controlSize(size)
            .buttonBorderShape(shape)
            .buttonSizing(width)
    }
    
    func secondaryButton(size: ControlSize = .large, width: ButtonSizing = .automatic, shape: ButtonBorderShape = .capsule) -> some View {
        self
            .buttonStyle(.glass)
            .controlSize(size)
            .buttonBorderShape(shape)
            .buttonSizing(width)
    }
    
    func tertiaryButton(size: ControlSize = .large, tint: Color = .primary) -> some View {
        self
            .buttonStyle(.borderless)
            .controlSize(size)
            .tint(tint)
    }
}

// MARK: - Preview
/*
#Preview("Button Styles Matrix") {
    ScrollView {
        VStack(spacing: 32) {
            // Header
            Text("TMButton Styles")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            // Primary
            VStack(alignment: .leading, spacing: 12) {
                Text("Primary")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button("Action") { }
                        .tmPrimary()

                    Button {} label: {
                        Label("Avec icône", systemImage: "play.fill")
                    }
                    .tmPrimary()
                }

                Button("Full Width") { }
                    .tmPrimary()
                    .frame(maxWidth: .infinity)
            }

            Divider()

            // Secondary
            VStack(alignment: .leading, spacing: 12) {
                Text("Secondary")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button("Action") { }
                        .tmSecondary()

                    Button {} label: {
                        Label("Avec icône", systemImage: "pencil")
                    }
                    .tmSecondary()
                }

                Button("Full Width") { }
                    .tmSecondary()
                    .frame(maxWidth: .infinity)
            }

            Divider()

            // Glass
            VStack(alignment: .leading, spacing: 12) {
                Text("Glass")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button("Action") { }
                        .tmGlass()

                    Button {} label: {
                        Label("Avec icône", systemImage: "arrow.right")
                    }
                    .tmGlass()
                }

                Button("Full Width") { }
                    .tmGlass()
                    .frame(maxWidth: .infinity)
            }

            Divider()

            // States
            VStack(alignment: .leading, spacing: 12) {
                Text("États")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button("Enabled") { }
                        .tmPrimary()

                    Button("Disabled") { }
                        .tmPrimary()
                        .disabled(true)
                }

                HStack(spacing: 16) {
                    Button("Enabled") { }
                        .tmSecondary()

                    Button("Disabled") { }
                        .tmSecondary()
                        .disabled(true)
                }
            }
        }
        .padding(24)
    }
    .preferredColorScheme(.dark)
}
*/
