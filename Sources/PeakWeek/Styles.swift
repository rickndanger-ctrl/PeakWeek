import SwiftUI

// MARK: - Square, flat control styles
// Design language: hard edges, hairline borders, no corner radii anywhere.

/// Flat square text field: plain field on an inset panel with a 1px border.
struct SquareFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.iron)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

extension View {
    func squareFieldStyle() -> some View { modifier(SquareFieldStyle()) }
}

/// Flat square action button (replaces borderedProminent).
struct SquareButtonStyle: ButtonStyle {
    var fill: Color = Theme.plateRed
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(fill.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(foreground)
            .overlay(Rectangle().stroke(Color.black.opacity(0.25), lineWidth: 1))
    }
}

/// Flat square secondary button (replaces bordered).
struct SquareOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(configuration.isPressed ? Theme.iron3 : Theme.iron2)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}
