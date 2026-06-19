import SwiftUI
import MiseShared

/// Frame 05 — Dish detail. Hero image, bilingual copy, tags, add-to-picks.
struct DishDetailView: View {
    let dish: Dish
    @Environment(ScanSession.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                header
                DishTagStrip(dish: dish)
                descriptions
                if !dish.ingredients.isEmpty { ingredients }
            }
            .padding()
            .padding(.bottom, 88)
        }
        .background(Theme.page)
        .navigationTitle(dish.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { addButton }
    }

    private var hero: some View {
        AsyncImage(url: dish.imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Theme.skeleton.overlay(
                    Image(systemName: "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.muted)
                )
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: Theme.Metrics.corner))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dish.name)
                .font(.serifTitle(28, weight: .bold))
                .foregroundStyle(Theme.ink)
            if let original = dish.originalName, original != dish.name {
                Text(original)
                    .font(.title3)
                    .italic()
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 10) {
                if let price = dish.price {
                    Text(formattedPrice(price, currency: dish.currency))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
                if dish.isPopular {
                    Pill(text: "popular · ordered a lot", systemImage: "star.fill",
                         fg: Theme.accentDark, bg: Theme.accentTint)
                }
            }
            .padding(.top, 2)
        }
    }

    private var descriptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let description = dish.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }
            if let original = dish.originalDescription, !original.isEmpty,
               original != dish.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In the original")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    Text(original)
                        .font(.callout)
                        .italic()
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 4)
            }
        }
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INGREDIENTS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            FlowLayout {
                ForEach(dish.ingredients, id: \.self) { ingredient in
                    Pill(text: ingredient.capitalized)
                }
            }
        }
    }

    private var addButton: some View {
        let picked = session.isPicked(dish)
        return Button { session.togglePick(dish) } label: {
            Label(picked ? "In my picks" : "Add to my picks",
                  systemImage: picked ? "checkmark" : "plus")
                .font(.headline)
                .foregroundStyle(picked ? Theme.accentDark : .white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(picked ? Theme.accentTint : Theme.accent,
                            in: .rect(cornerRadius: Theme.Metrics.corner))
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    NavigationStack {
        DishDetailView(dish: ScanSession.previewLoaded.menu!.dishes[0])
    }
    .environment(ScanSession.previewLoaded)
}
