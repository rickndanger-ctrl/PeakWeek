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

/// Numeric field for optional Doubles that lets the user TYPE freely
/// (decimals, minus signs, partial input) and commits on submit / focus loss.
/// A plain string<->number binding re-formats every keystroke and eats "."
/// mid-edit; this keeps the typed text authoritative while editing.
struct OptionalNumberField: View {
    let placeholder: String
    @Binding var value: Double?
    var width: CGFloat = 56

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .squareFieldStyle()
            .font(.system(.caption, design: .monospaced))
            .multilineTextAlignment(.center)
            .frame(width: width)
            .focused($focused)
            .onAppear { text = Self.format(value) }
            .onChange(of: value) { newValue in
                if !focused { text = Self.format(newValue) }
            }
            .onChange(of: focused) { isFocused in
                if !isFocused { commit() }
            }
            .onSubmit { commit() }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        value = trimmed.isEmpty ? nil : Double(trimmed)
        text = Self.format(value)
    }

    static func format(_ v: Double?) -> String {
        guard let v else { return "" }
        return v == v.rounded() ? String(Int(v)) : String(v)
    }
}
