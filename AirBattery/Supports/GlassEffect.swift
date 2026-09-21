import AppKit
import SwiftUI

private struct AirBatteryGlassEffectModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    shape.stroke(
                        Color.primary.opacity(0.18),
                        lineWidth: 1
                    )
                )
        } else {
            content.glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: shape
            )
        }
    }
}

extension View {
    func liquidGlassEffect<S: Shape>(
        in shape: S,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        modifier(
            AirBatteryGlassEffectModifier(
                shape: shape,
                interactive: interactive,
                tint: tint
            )
        )
    }

    func liquidGlassEffect(
        cornerRadius: CGFloat,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        liquidGlassEffect(
            in: RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            ),
            interactive: interactive,
            tint: tint
        )
    }
}
