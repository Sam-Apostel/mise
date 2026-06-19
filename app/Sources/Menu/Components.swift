import SwiftUI
import MiseShared

/// A small rounded chip used for tags, counts, and toggles.
struct Pill: View {
    var text: String
    var systemImage: String?
    var fg: Color = Theme.inkSoft
    var bg: Color = Theme.hairline.opacity(0.5)

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let systemImage { Image(systemName: systemImage) }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption.weight(.medium))
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(bg, in: .capsule)
    }
}

/// Horizontal strip of a dish's dietary/spice/allergen tags.
struct DishTagStrip: View {
    let dish: Dish

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if dish.isPopular {
                    Pill(text: "popular", systemImage: "star.fill",
                         fg: Theme.accentDark, bg: Theme.accentTint)
                }
                if dish.spiceLevel != .none {
                    Pill(text: dish.spiceLevel.chiliIndicator,
                         fg: Theme.accentDark, bg: Theme.spiceBg)
                }
                ForEach(dish.dietaryTags, id: \.self) { tag in
                    Pill(text: tag.displayName, systemImage: tag.systemImageName,
                         fg: tag.palette.fg, bg: tag.palette.bg)
                }
                ForEach(dish.allergens, id: \.self) { allergen in
                    Pill(text: "contains \(allergen.displayName.lowercased())",
                         fg: allergen.palette.fg, bg: allergen.palette.bg)
                }
            }
        }
    }
}

/// Square dish thumbnail with a tasteful placeholder until images are enriched.
struct DishThumbnail: View {
    let dish: Dish
    var size: CGFloat = Theme.Metrics.thumb

    var body: some View {
        AsyncImage(url: dish.imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Theme.skeleton.overlay(
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Theme.muted)
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 10))
    }
}

/// Formats a price with its dish/menu currency.
func formattedPrice(_ price: Decimal, currency: String?) -> String {
    price.formatted(.currency(code: currency ?? "EUR"))
}

/// A simple left-aligned wrapping layout for chips/tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A selectable chip with an optional trailing count, used throughout Filters.
struct FilterChip: View {
    var text: String
    var count: Int?
    var isSelected: Bool
    var selectedFg: Color = .white
    var selectedBg: Color = Theme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(text)
                if let count { Text("\(count)").opacity(0.7) }
                if isSelected { Image(systemName: "checkmark") }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? selectedFg : Theme.inkSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? selectedBg : Theme.paper, in: .capsule)
            .overlay(Capsule().stroke(isSelected ? .clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
