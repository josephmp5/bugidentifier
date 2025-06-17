import SwiftUI

extension Color {
    static let appThemePrimary = Color("ThemePrimary") // #38761D or similar
    static let themeAccent = Color.green // A brighter green for accents if needed
    static let themeBackground = Color(UIColor.systemBackground)
    static let themeSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let themeCardBackground = Color(UIColor.tertiarySystemBackground)
    static let themeText = Color(UIColor.label)
    static let themeSecondaryText = Color(UIColor.secondaryLabel)
    static let themeOrange = Color(hex: "#FF6F00") // A vibrant orange
}

// Helper to initialize Color from hex string
extension Color {
    init(hex: String) {
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
