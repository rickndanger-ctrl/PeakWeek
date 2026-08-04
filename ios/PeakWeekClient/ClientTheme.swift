import SwiftUI

/// Same design language as the coach app: square corners, semantic system
/// colors, IPF plate colors as data accents only.
enum ClientTheme {
    static let accent = Color(red: 0.239, green: 0.42, blue: 0.71)      // plate blue
    static let plateRed = Color(red: 0.788, green: 0.275, blue: 0.235)
    static let plateGreen = Color(red: 0.243, green: 0.557, blue: 0.361)
    static let plateYellow = Color(red: 0.863, green: 0.663, blue: 0.247)

    static func phaseColor(_ label: String) -> Color {
        switch label.lowercased() {
        case let s where s.contains("accum"): return accent
        case let s where s.contains("transmut"): return plateYellow
        case let s where s.contains("realiz"): return plateRed
        case let s where s.contains("deload"): return plateGreen
        case let s where s.contains("meet"): return .primary
        default: return .purple
        }
    }
}

/// Square panel — the app's one visual signature.
struct SquareCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(Rectangle().stroke(Color(.separator), lineWidth: 0.5))
    }
}

extension View {
    func squareCard() -> some View { modifier(SquareCard()) }
}
