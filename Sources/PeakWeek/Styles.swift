import SwiftUI

// MARK: - Shared controls
// The app uses NATIVE macOS control styles (bordered / borderedProminent /
// roundedBorder fields) and semantic system colors — see Theme. Custom chrome
// is limited to layout containers.

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
            .textFieldStyle(.roundedBorder)
            .font(.system(.caption, design: .monospaced))
            .multilineTextAlignment(.center)
            .frame(width: width)
            .focused($focused)
            .onAppear { text = Self.format(value) }
            .onChange(of: value) { newValue in
                if !focused { text = Self.format(newValue) }
            }
            .onChange(of: text) { newText in
                // Live-sync valid values while typing (WITHOUT reformatting the
                // text, so decimals type normally). Buttons on macOS don't steal
                // focus, so waiting for blur alone could let "Copy week" read a
                // stale value.
                guard focused else { return }
                let t = newText.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: ".")
                if t.isEmpty { value = nil }
                else if let d = Double(t) { value = d }
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
