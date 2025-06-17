import SwiftUI

// ThemeColors struct will be the single source of truth for app theme colors.
// It uses the hex initializer defined below.
struct ThemeColors {
    static let background = colorFrom(hex: "F7F6F1")      // Off-white
    static let primaryText = colorFrom(hex: "2C3D34")   // Deep Forest Green
    static let accent = colorFrom(hex: "D4B79E")       // Warm Tan
    static let cardBackground = Color.white                 // True White for cards
    static let serifText = Color.black                      // Black for serif titles

    // Private helper function to convert hex to Color, scoped to this struct.
    // This avoids conflicts with any other `Color(hex:)` initializers in the project.
    private static func colorFrom(hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // Default to black if hex is invalid
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
