import SwiftUI
import MiseShared

/// A drawn plate, top-down, in the one hand of the mockups: the last tier of the
/// image chain and what every tile shows while photos load.
struct PlateArtwork: View {
    let plate: PlateArchetype

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 160
            context.translateBy(x: (size.width - 160 * scale) / 2, y: (size.height - 160 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            // The plate itself.
            let rim = Path(ellipseIn: CGRect(x: 4, y: 4, width: 152, height: 152))
            context.fill(rim, with: .color(Ink.plate.color))
            context.stroke(rim, with: .color(Ink.rim.color), lineWidth: 2)
            for element in Self.elements(for: plate) {
                element.draw(in: &context)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The illustration palette from the B exploration.
enum Ink {
    case rice, broth, amber, tan, herb, leaf, chili, plate, rim
    case hex(UInt32)

    var color: Color {
        switch self {
        case .rice: Color(hex: 0xF3ECD6)
        case .broth: Color(hex: 0xF1DDA2)
        case .amber: Color(hex: 0xE0A94A)
        case .tan: Color(hex: 0xD9BC8B)
        case .herb: Color(hex: 0x3E8A5E)
        case .leaf: Color(hex: 0x2C6B48)
        case .chili: Color(hex: 0xC3321F)
        case .plate: Color(hex: 0xF8F1E0)
        case .rim: Color(hex: 0xE4DCC8)
        case .hex(let value): Color(hex: value)
        }
    }
}

/// One SVG element of a plate, in the 160×160 artboard.
enum PlateElement {
    case circle(cx: CGFloat, cy: CGFloat, r: CGFloat, fill: Ink?, stroke: Ink?, width: CGFloat, opacity: Double)
    case ellipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, fill: Ink?, opacity: Double)
    case rect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, rx: CGFloat, fill: Ink?, opacity: Double)
    case path(String, fill: Ink?, stroke: Ink?, width: CGFloat, opacity: Double)

    func draw(in context: inout GraphicsContext) {
        switch self {
        case let .circle(cx, cy, r, fill, stroke, width, opacity):
            let shape = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            paint(shape, fill: fill, stroke: stroke, width: width, opacity: opacity, in: &context)
        case let .ellipse(cx, cy, rx, ry, fill, opacity):
            let shape = Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry))
            paint(shape, fill: fill, stroke: nil, width: 0, opacity: opacity, in: &context)
        case let .rect(x, y, w, h, rx, fill, opacity):
            let shape = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: rx)
            paint(shape, fill: fill, stroke: nil, width: 0, opacity: opacity, in: &context)
        case let .path(d, fill, stroke, width, opacity):
            paint(SVGPath.parse(d), fill: fill, stroke: stroke, width: width, opacity: opacity, in: &context)
        }
    }

    private func paint(_ shape: Path, fill: Ink?, stroke: Ink?, width: CGFloat, opacity: Double,
                       in context: inout GraphicsContext) {
        var layer = context
        layer.opacity = opacity
        if let fill { layer.fill(shape, with: .color(fill.color)) }
        if let stroke, width > 0 {
            layer.stroke(shape, with: .color(stroke.color),
                         style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }
}

/// A small SVG path-data parser: M L H V C S Q A Z, absolute and relative.
/// Enough for the hand-drawn plates; not a general SVG implementation.
enum SVGPath {
    static func parse(_ data: String) -> Path {
        var path = Path()
        var tokens = Tokenizer(data)
        var current = CGPoint.zero, start = CGPoint.zero
        var lastControl: CGPoint?
        var command: Character = "M"

        while let next = tokens.nextCommandOrNumber() {
            if case .command(let c) = next { command = c } else { tokens.pushBack(next) }
            let relative = command.isLowercase
            func pt() -> CGPoint? {
                guard let x = tokens.number(), let y = tokens.number() else { return nil }
                return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }
            switch command.uppercased().first! {
            case "M":
                guard let p = pt() else { return path }
                path.move(to: p); current = p; start = p; lastControl = nil
                command = relative ? "l" : "L" // further pairs are implicit line-tos
            case "L":
                guard let p = pt() else { return path }
                path.addLine(to: p); current = p; lastControl = nil
            case "H":
                guard let x = tokens.number() else { return path }
                current.x = relative ? current.x + x : x
                path.addLine(to: current); lastControl = nil
            case "V":
                guard let y = tokens.number() else { return path }
                current.y = relative ? current.y + y : y
                path.addLine(to: current); lastControl = nil
            case "C":
                guard let c1 = pt(), let c2 = pt(), let p = pt() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2); current = p; lastControl = c2
            case "S":
                let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                guard let c2 = pt(), let p = pt() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2); current = p; lastControl = c2
            case "Q":
                guard let c = pt(), let p = pt() else { return path }
                path.addQuadCurve(to: p, control: c); current = p; lastControl = nil
            case "A":
                guard let rx = tokens.number(), let ry = tokens.number(), let rot = tokens.number(),
                      let large = tokens.number(), let sweep = tokens.number(), let p = pt() else { return path }
                addArc(to: &path, from: current, to: p, rx: rx, ry: ry, rotation: rot,
                       largeArc: large != 0, sweep: sweep != 0)
                current = p; lastControl = nil
            case "Z":
                path.closeSubpath(); current = start; lastControl = nil
            default:
                return path
            }
        }
        return path
    }

    /// SVG endpoint arc → centre parameterisation (SVG 1.1, appendix F.6), drawn as an ellipse arc.
    private static func addArc(to path: inout Path, from p0: CGPoint, to p1: CGPoint, rx: CGFloat, ry: CGFloat,
                               rotation: CGFloat, largeArc: Bool, sweep: Bool) {
        var rx = abs(rx), ry = abs(ry)
        guard rx > 0, ry > 0, p0 != p1 else { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosP * dx + sinP * dy, y1 = -sinP * dx + cosP * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= lambda.squareRoot(); ry *= lambda.squareRoot() }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = (max(0, num) / den).squareRoot()
        if largeArc == sweep { coef = -coef }
        let cx1 = coef * rx * y1 / ry, cy1 = -coef * ry * x1 / rx
        let cx = cosP * cx1 - sinP * cy1 + (p0.x + p1.x) / 2
        let cy = sinP * cx1 + cosP * cy1 + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let theta1 = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var delta = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi } else if sweep && delta < 0 { delta += 2 * .pi }
        let steps = max(2, Int(abs(delta) / (.pi / 16)))
        for i in 1...steps {
            let t = theta1 + delta * CGFloat(i) / CGFloat(steps)
            let x = cx + rx * cos(t) * cosP - ry * sin(t) * sinP
            let y = cy + rx * cos(t) * sinP + ry * sin(t) * cosP
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }

    private struct Tokenizer {
        enum Token { case command(Character), number(CGFloat) }
        private let chars: [Character]
        private var index = 0
        private var pending: Token?

        init(_ s: String) { chars = Array(s) }

        mutating func pushBack(_ token: Token) { pending = token }

        mutating func nextCommandOrNumber() -> Token? {
            if let p = pending { pending = nil; return p }
            skipSeparators()
            guard index < chars.count else { return nil }
            let c = chars[index]
            if c.isLetter, c != "e", c != "E" { index += 1; return .command(c) }
            return readNumber().map { .number($0) }
        }

        mutating func number() -> CGFloat? {
            if let p = pending {
                pending = nil
                if case .number(let n) = p { return n }
                return nil
            }
            skipSeparators()
            return readNumber()
        }

        private mutating func skipSeparators() {
            while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index].isNewline {
                index += 1
            }
        }

        private mutating func readNumber() -> CGFloat? {
            var s = ""
            var seenDot = false, seenExp = false
            while index < chars.count {
                let c = chars[index]
                if c == "-" || c == "+" {
                    if !s.isEmpty && !(s.last == "e" || s.last == "E") { break }
                } else if c == "." {
                    if seenDot || seenExp { break }
                    seenDot = true
                } else if c == "e" || c == "E" {
                    if seenExp { break }
                    seenExp = true
                } else if !c.isNumber {
                    break
                }
                s.append(c); index += 1
            }
            return Double(s).map { CGFloat($0) }
        }
    }
}
