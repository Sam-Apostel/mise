import SwiftUI
import MiseShared

// MARK: - Photos

/// A dish photo cropped to fill, warmed and lifted a touch so mismatched
/// sources read as one set; the drawn plate when there is none (yet).
struct DishPhoto: View {
    let dish: Dish
    var plateScale: CGFloat = 0.72
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Board.tile
            if let url = dish.imageURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .saturation(1.05).contrast(1.1)
                            .colorMultiply(scheme == .dark ? Color(white: 0.88) : .white)
                    default:
                        plate
                    }
                }
            } else {
                plate
            }
        }
        .clipped()
    }

    private var plate: some View {
        GeometryReader { proxy in
            PlateArtwork(plate: dish.plate)
                .frame(width: min(proxy.size.width * plateScale, proxy.size.height * 0.96))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The painted "02 · ฿95" chip in the ground colour, notched into the photo's corner.
struct NumberChip: View {
    let text: String
    var leading: CGFloat = 8
    var fill: Color = Board.ground
    var ink: Color = Board.ink
    var font: Font = .boardChip

    var body: some View {
        Text(text)
            .font(font)
            .tracking(-0.3)
            .monospacedDigit()
            .foregroundStyle(ink)
            .lineLimit(1)
            .padding(.leading, leading)
            .padding(.trailing, 10)
            .padding(.top, 5)
            .padding(.bottom, 3)
            .background(fill, in: UnevenRoundedRectangle(topTrailingRadius: 8))
    }
}

// MARK: - Chrome

/// A 44pt glass circle in the top bar.
struct GlassCircleButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Board.ink)
                .frame(width: size, height: size)
                .contentShape(.circle)
        }
        .buttonStyle(PressStyle())
        .boardGlass(in: Circle())
        .accessibilityLabel(label)
    }
}

/// A 44pt glass capsule with an icon and a label ("Picks · 2").
struct GlassCapsuleButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 17, weight: .medium))
                Text(title).font(.system(size: 15, weight: .semibold)).tracking(-0.2)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Board.ink)
            .padding(.leading, 14).padding(.trailing, 16)
            .frame(height: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(PressStyle())
        .boardGlass(in: Capsule())
    }
}

/// The thumb-zone call to action: a 56pt capsule.
struct BoardCTA: View {
    enum Style { case cream, outline, paint }
    let title: String
    var systemImage: String?
    var style: Style = .cream
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 18, weight: .medium)) }
                Text(title).font(.system(size: 17, weight: .semibold)).tracking(-0.4)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(background, in: Capsule())
            .overlay {
                if style == .outline { Capsule().strokeBorder(Board.ink, lineWidth: 1.5) }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(PressStyle())
    }

    private var foreground: Color {
        switch style {
        case .cream: Board.ground
        case .outline: Board.ink
        case .paint: Board.raised
        }
    }

    private var background: Color {
        switch style {
        case .cream: Board.ink
        case .outline: .clear
        case .paint: Board.paint
        }
    }
}

/// The bottom fade that keeps body text from reading under floating controls.
struct BottomFade: View {
    var color: Color = Board.ground
    var height: CGFloat = 150

    var body: some View {
        LinearGradient(stops: [
            .init(color: color.opacity(0), location: 0),
            .init(color: color.opacity(0.92), location: 0.42),
            .init(color: color, location: 0.62),
        ], startPoint: .top, endPoint: .bottom)
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - On the board

/// A person in the people row: outline at rest, filled cream with a check when selected.
struct PersonChip: View {
    let title: String
    let isOn: Bool
    var dashed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isOn {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(isOn ? Board.ground : (dashed ? Board.ink2 : Board.ink))
            .padding(.horizontal, dashed ? 14 : 16)
            .frame(height: 40)
            .background(isOn ? Board.ink : .clear, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isOn ? Board.ink : Board.rule,
                                       style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [4, 3] : []))
            }
            .contentShape(.capsule)
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - On cream (sheets)

/// A chip on a cream sheet: outline at rest; painted green when on, deep red for allergens.
struct CreamChip: View {
    let title: String
    var detail: String?
    let isOn: Bool
    var onColor: Color = Board.paint
    var showsCheck = false
    /// Replaces the checkmark when on ("plus" for wanted, "minus" for avoided).
    var icon = "checkmark"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isOn && showsCheck {
                    Image(systemName: icon).font(.system(size: 13, weight: .bold))
                }
                Text(title).font(.system(size: 15, weight: .semibold))
                if let detail {
                    Text(detail).font(.system(size: 15))
                        .foregroundStyle(isOn ? Board.raised.opacity(0.8) : Board.onRaised2)
                }
            }
            .foregroundStyle(isOn ? (onColor == Board.noDeep ? .white : Board.raised) : Board.onRaised)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(isOn ? onColor : .clear, in: Capsule())
            .overlay { Capsule().strokeBorder(isOn ? onColor : Board.onRaised.opacity(0.22), lineWidth: 1.5) }
            .contentShape(.capsule)
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The spice segmented control on cream: Any/None · Mild · Medium · Hot with amber chilis.
struct SpiceSegments: View {
    var firstTitle: String
    @Binding var level: SpiceLevel?

    var body: some View {
        HStack(spacing: 2) {
            segment(firstTitle, value: nil, chilis: 0)
            segment("Mild", value: .mild, chilis: 1)
            segment("Medium", value: .medium, chilis: 2)
            segment("Hot", value: .hot, chilis: 3)
        }
        .padding(3)
        .frame(height: 44)
        .background(Board.onRaised.opacity(0.07), in: Capsule())
    }

    private func segment(_ title: String, value: SpiceLevel?, chilis: Int) -> some View {
        let on = level == value
        return Button {
            withAnimation(.snappy) { level = value }
        } label: {
            HStack(spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                if chilis > 0 { Chilis(count: chilis, size: 8) }
            }
            .foregroundStyle(on ? Board.raised : Board.onRaised2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(on ? Board.paint : .clear, in: Capsule())
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A section label on cream with optional trailing detail.
struct CreamGroupHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).boardLabelStyle()
            Spacer()
            if let detail { Text(detail).font(.boardMeta).monospacedDigit() }
        }
        .foregroundStyle(Board.onRaised2)
        .padding(.bottom, 10)
    }
}

/// Wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
