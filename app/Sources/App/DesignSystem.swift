import SwiftUI
import MiseShared

/// Design tokens lifted from the Menu Copilot wireframes.
enum Theme {
    // Surfaces
    static let page = Color(hex: 0xECE7DD)       // app background
    static let paper = Color(hex: 0xFBF8F1)      // cards / screen surface
    static let skeleton = Color(hex: 0xE1D9C6)   // image placeholders / thumbnails
    static let topBar = Color(hex: 0x2B2B2B)     // dark pinned bar

    // Text
    static let ink = Color(hex: 0x2B2B2B)
    static let inkSoft = Color(hex: 0x444038)
    static let muted = Color(hex: 0x9B958A)
    static let hairline = Color(hex: 0xCFC7B5)

    // Accent
    static let accent = Color(hex: 0xE8743B)
    static let accentDark = Color(hex: 0xC2531F)
    static let accentTint = Color(hex: 0xFDEEE6)

    // Semantic (dietary / allergen / spice)
    static let veg = Color(hex: 0x2E7D4F)
    static let vegBg = Color(hex: 0xD9EFDF)
    static let alert = Color(hex: 0xB03030)
    static let alertBg = Color(hex: 0xFDD9D9)
    static let warn = Color(hex: 0x9A7400)
    static let warnBg = Color(hex: 0xFDECC2)
    static let spiceBg = Color(hex: 0xFDE2CF)

    enum Metrics {
        static let corner: CGFloat = 14
        static let chipCorner: CGFloat = 999
        static let thumb: CGFloat = 56
    }
}

extension Font {
    /// Serif treatment used for dish & restaurant names (editorial feel).
    static func serifTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Semantic colours for tags

extension DietaryTag {
    /// (foreground, background) for the dietary chip.
    var palette: (fg: Color, bg: Color) {
        switch self {
        case .vegan, .vegetarian, .healthy, .pescatarian:
            return (Theme.veg, Theme.vegBg)
        case .spicy:
            return (Theme.accentDark, Theme.spiceBg)
        case .containsAlcohol, .containsPork:
            return (Theme.alert, Theme.alertBg)
        default:
            return (Theme.inkSoft, Theme.hairline.opacity(0.5))
        }
    }
}

extension Allergen {
    var palette: (fg: Color, bg: Color) { (Theme.alert, Theme.alertBg) }
}
