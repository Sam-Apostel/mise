import SwiftUI
import MiseShared

/// A numbered photo tile: photo with its painted chip, name, original script or
/// gloss, and one line that is the description, the reason, or the question.
struct DishTile: View {
    let dish: Dish
    /// Drives the strike and the desaturation (switches first, at 0 ms).
    let strike: Verdict
    /// Drives the reason line and the ask mark (fades in at 260 ms).
    let reason: Verdict
    let chip: String
    /// Latin-script menus title the tile with the dish's own name and gloss it in English.
    let titleInOriginal: Bool
    let showsDescription: Bool

    private var crossed: Bool { strike.kind == .no }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            photo
            Text(title)
                .font(.boardName)
                .boardCaps()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(crossed ? Board.ink3 : Board.ink)
            HStack(spacing: 6) {
                if let subtitle {
                    Text(subtitle).font(.boardSecondary).lineLimit(1)
                        .foregroundStyle(crossed ? Board.ink3 : Board.ink2)
                }
                if !crossed {
                    if dish.spiceLevel.level > 0 { Chilis(count: dish.spiceLevel.level) }
                    if dish.isPopular {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 9))
                            Text("popular").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Board.ink2)
                    }
                }
            }
            .padding(.top, -2)
            line
                .frame(minHeight: 40, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String { titleInOriginal ? (dish.originalName ?? dish.name) : dish.name }
    private var subtitle: String? {
        titleInOriginal ? (dish.originalName == nil ? nil : dish.name) : dish.originalName
    }

    private var photo: some View {
        // A clear 4:3 frame first, so the photo's own size never leaks into the grid.
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                DishPhoto(dish: dish)
                    .saturation(crossed ? 0.25 : 1)
                    .colorMultiply(crossed ? Color(white: 0.55) : .white)
            }
            .overlay { ChalkStrike(progress: crossed ? 1 : 0) }
            .overlay(alignment: .bottomLeading) { NumberChip(text: chip) }
            .overlay(alignment: .topTrailing) {
                if reason.kind == .ask {
                    AskMark().transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: Board.tileRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Board.tileRadius).strokeBorder(Board.rule, lineWidth: 1)
            }
    }

    @ViewBuilder
    private var line: some View {
        switch reason.kind {
        case .no:
            Text(reason.reason ?? "Not for you")
                .font(.system(size: 15, weight: .semibold)).tracking(-0.2)
                .foregroundStyle(Board.no)
                .lineLimit(2)
                .transition(.opacity)
        case .ask:
            Text(reason.reason ?? "Ask.")
                .font(.system(size: 15, weight: .semibold)).tracking(-0.2)
                .foregroundStyle(Board.ask)
                .lineLimit(2)
                .transition(.opacity)
        case .fine:
            if showsDescription, let description = dish.description {
                Text(description)
                    .font(.boardSecondary).tracking(-0.2)
                    .foregroundStyle(Board.ink3)
                    .lineLimit(2)
                    .transition(.opacity)
            }
        }
    }
}
