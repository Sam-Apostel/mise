import SwiftUI
import UIKit
import MiseShared

// The board: a painted green menu board by day, slate by night, cream lettering.
// Tokens from design/DIRECTION.md ("Tokens") as amended by the board round-1 scan.

enum Board {
    // MARK: Colour

    /// The board. Painted green by day, green-black slate by night.
    static let ground = Color(light: 0x0D5236, dark: 0x182B21)
    /// Photo tile frame fill.
    static let tile = Color(light: 0xF8F1E0, lightAlpha: 0.10, dark: 0xF1ECE0, darkAlpha: 0.08)
    /// Cream lettering, chalk at night.
    static let ink = Color(light: 0xF8F1E0, dark: 0xF1ECE0)
    static let ink2 = Color(light: 0xC9D1BE, dark: 0xB8B7AD)
    static let ink3 = Color(light: 0xB6C4B0, dark: 0x999A91)
    static let rule = Color(light: 0xF8F1E0, lightAlpha: 0.22, dark: 0xF1ECE0, darkAlpha: 0.16)

    /// Cream card on the board: sheets, the waiter card. Cream in both modes.
    static let raised = Color(hex: 0xF8F1E0)
    static let onRaised = Color(hex: 0x1B211E)
    static let onRaised2 = Color(hex: 0x4C524D)
    static let raisedRule = Color(hex: 0x1B211E, alpha: 0.12)
    /// The painted green, used for controls on cream in both modes.
    static let paint = Color(hex: 0x0D5236)

    /// One job: "not for you". The strike, the reason line.
    static let no = Color(hex: 0xFFA592)
    /// "Not for you" on cream: the allergy block, selected allergens.
    static let noDeep = Color(hex: 0xB8321F)
    /// "Ask first": the ? mark and the ask line. Also the chilis.
    static let ask = Color(hex: 0xE8B84A)

    /// Glass fallback before iOS 26.
    static let glassTint = Color(hex: 0x041E13, alpha: 0.38)

    // MARK: Space

    static let margin: CGFloat = 20
    static let gutter: CGFloat = 12
    static let tileRadius: CGFloat = 10
    static let cardRadius: CGFloat = 26
}

// MARK: - Type

extension Font {
    /// Restaurant name, waiter-card lines. Bricolage 800, width 80, caps. 44/44.
    static let boardDisplay = Font.custom("MiseBoard-Display", size: 44, relativeTo: .largeTitle)
    /// Menu numbers and summary counts. 34/34.
    static let boardNumber = Font.custom("MiseBoard-Heavy", size: 34, relativeTo: .title)
    /// Dish names on tiles and rows, sheet titles. 20/22.
    static let boardName = Font.custom("MiseBoard-Heavy", size: 20, relativeTo: .title3)
    /// Number-and-price chip on a photo.
    static let boardChip = Font.custom("MiseBoard-Heavy", size: 20, relativeTo: .title3)
    /// Section labels. Bricolage 700 caps, 13/17, tracking +1.
    static let boardLabel = Font.custom("MiseBoard-Label", size: 13, relativeTo: .footnote)

    /// SF steps: body 17/22, secondary 15/20, meta 13/17.
    static let boardBody = Font.system(size: 17, weight: .regular)
    static let boardSecondary = Font.system(size: 15, weight: .regular)
    static let boardMeta = Font.system(size: 13, weight: .regular)

    static func boardHeavy(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("MiseBoard-Heavy", size: size, relativeTo: style)
    }
}

extension View {
    /// Bricolage display treatment: uppercase, tight tracking.
    func boardCaps(tracking: CGFloat = 0) -> some View {
        textCase(.uppercase).tracking(tracking)
    }

    /// Section label: Bricolage 700 caps, +1 tracking.
    func boardLabelStyle() -> some View {
        font(.boardLabel).textCase(.uppercase).tracking(1)
    }

    /// Liquid Glass on iOS 26, a dark tinted material before it.
    @ViewBuilder
    func boardGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(Board.glassTint).interactive(), in: shape)
        } else {
            background(Board.glassTint, in: shape)
                .background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Colour helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    /// A colour that follows the light/dark appearance.
    init(light: UInt32, lightAlpha: Double = 1, dark: UInt32, darkAlpha: Double = 1) {
        self.init(uiColor: UIColor { traits in
            let (hex, alpha) = traits.userInterfaceStyle == .dark ? (dark, darkAlpha) : (light, lightAlpha)
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: alpha)
        })
    }
}

// MARK: - Small drawn marks

/// The amber chili from the mockups, repeated per spice level.
struct Chilis: View {
    var count: Int
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<count, id: \.self) { _ in
                ChiliShape()
                    .fill(Board.ask)
                    .frame(width: size, height: size * 13 / 11)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(["", "mild", "medium", "hot"][min(count, 3)])
    }
}

/// `M9.5 1.5c.4 1.6-.2 3-1.4 3.8 M8.2 4.6C9.6 7.4 7.8 12 4.2 12.6 1.4 13 .4 10 1.6 7.6 2.6 5.6 5 4.4 8.2 4.6z` in a 12×14 box.
struct ChiliShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 12, sy = rect.height / 14
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var body = Path()
        body.move(to: p(8.2, 4.6))
        body.addCurve(to: p(4.2, 12.6), control1: p(9.6, 7.4), control2: p(7.8, 12))
        body.addCurve(to: p(1.6, 7.6), control1: p(1.4, 13), control2: p(0.4, 10))
        body.addCurve(to: p(8.2, 4.6), control1: p(2.6, 5.6), control2: p(5, 4.4))
        body.closeSubpath()
        var stem = Path()
        stem.move(to: p(9.5, 1.5))
        stem.addCurve(to: p(8.1, 5.3), control1: p(9.9, 3.1), control2: p(9.3, 4.5))
        body.addPath(stem.strokedPath(StrokeStyle(lineWidth: 1.4 * sx, lineCap: .round)))
        return body
    }
}
