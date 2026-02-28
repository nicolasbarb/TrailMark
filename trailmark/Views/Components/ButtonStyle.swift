import SwiftUI

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
