import SwiftUI

/// The signature: a red chalk line across a photo the selected person cannot have.
///
/// A tapered, slightly wobbly stroke drawn as a filled shape (thin at the start,
/// widest past the middle), running about 5° shallower than the diagonal.
/// `progress` reveals it left to right, so it draws in and erases back along its path.
struct ChalkStrike: View {
    var progress: CGFloat
    var color: Color = Board.no

    var body: some View {
        StrikeShape()
            .fill(color)
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .frame(width: proxy.size.width * (0.05 + 0.95 * progress))
                }
            }
            .opacity(progress > 0 ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// `M10 17 C34 30 64 46 98 64 C120 76 138 86 151 95 C153 97 151 99 148 98
///  C134 92 116 82 95 70 C62 52 32 36 9 20 C8 19 8 17 10 17 Z` in a 160×120 box, stretched.
struct StrikeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 160, sy = rect.height / 120
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        path.move(to: p(10, 17))
        path.addCurve(to: p(98, 64), control1: p(34, 30), control2: p(64, 46))
        path.addCurve(to: p(151, 95), control1: p(120, 76), control2: p(138, 86))
        path.addCurve(to: p(148, 98), control1: p(153, 97), control2: p(151, 99))
        path.addCurve(to: p(95, 70), control1: p(134, 92), control2: p(116, 82))
        path.addCurve(to: p(9, 20), control1: p(62, 52), control2: p(32, 36))
        path.addCurve(to: p(10, 17), control1: p(8, 19), control2: p(8, 17))
        path.closeSubpath()
        return path
    }
}

/// The mustard "?" in the photo's top-right corner of an "ask" tile.
struct AskMark: View {
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(bottomLeadingRadius: 8)
                .fill(Board.ask)
            Canvas { context, size in
                let s = size.width / 24
                var hook = Path()
                hook.move(to: CGPoint(x: 8.6 * s, y: 8.4 * s))
                hook.addCurve(to: CGPoint(x: 15.4 * s, y: 9.5 * s),
                              control1: CGPoint(x: 9.4 * s, y: 4.6 * s), control2: CGPoint(x: 15.4 * s, y: 5.6 * s))
                hook.addCurve(to: CGPoint(x: 12 * s, y: 14.6 * s),
                              control1: CGPoint(x: 15.4 * s, y: 11.8 * s), control2: CGPoint(x: 12 * s, y: 12.4 * s))
                context.stroke(hook, with: .color(Board.onRaised),
                               style: StrokeStyle(lineWidth: 2.8 * s, lineCap: .round))
                let dot = Path(ellipseIn: CGRect(x: (12 - 1.7) * s, y: (18.6 - 1.7) * s, width: 3.4 * s, height: 3.4 * s))
                context.fill(dot, with: .color(Board.onRaised))
            }
            .frame(width: 20, height: 20)
        }
        .frame(width: 34, height: 34)
        .accessibilityLabel("Ask first")
    }
}
