//
//  LiquidGlassCompat.swift
//  AirBattery
//
//  Created by Ryo on 2026/6/19.
//

import AppKit
import SwiftUI
import WidgetKit

private struct LiquidGlassEffectModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(shape.fill(Color(nsColor: .windowBackgroundColor)))
                .overlay(shape.stroke(Color.primary.opacity(0.18), lineWidth: 1))
        } else {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
        }
        #else
        content
        #endif
        }
    }
}

private struct LiquidGlassPanelModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(shape.fill(Color(nsColor: .windowBackgroundColor)))
                .overlay(shape.stroke(Color.primary.opacity(0.18), lineWidth: 1))
        } else {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            fallback(content: content)
        }
        #else
        fallback(content: content)
        #endif
        }
    }

    @ViewBuilder
    private func fallback(content: Content) -> some View {
        content
            .background(shape.fill(.thinMaterial))
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.7))
    }
}

extension View {
    func liquidGlassEffect<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(LiquidGlassEffectModifier(shape: shape, interactive: interactive, tint: tint))
    }

    func liquidGlassEffect(cornerRadius: CGFloat, interactive: Bool = false, tint: Color? = nil) -> some View {
        liquidGlassEffect(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            interactive: interactive,
            tint: tint
        )
    }

    func liquidGlassPanel<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(LiquidGlassPanelModifier(shape: shape, interactive: interactive, tint: tint))
    }

    func liquidGlassPanel(cornerRadius: CGFloat, interactive: Bool = false, tint: Color? = nil) -> some View {
        liquidGlassPanel(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            interactive: interactive,
            tint: tint
        )
    }

    @ViewBuilder
    func liquidGlassWidgetBackground(_ fallback: Color = Color("WidgetBackground")) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            containerBackground(for: .widget) {
                fallback
            }
        }
        #else
        containerBackground(for: .widget) {
            fallback
        }
        #endif
    }
}
