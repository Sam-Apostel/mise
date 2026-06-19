import SwiftUI
import MiseShared

/// Frame 04 — Dial in filters. Dietary / allergens / spice / ingredients with live counts.
struct FiltersView: View {
    @Bindable var model: MenuFilterModel
    let dishes: [Dish]
    @Environment(\.dismiss) private var dismiss

    /// Most common dietary tags present on this menu, for the dietary section.
    private var availableTags: [DietaryTag] {
        DietaryTag.allCases.filter { tag in dishes.contains { $0.dietaryTags.contains(tag) } }
    }

    private var availableAllergens: [Allergen] {
        Allergen.allCases.filter { allergen in dishes.contains { $0.allergens.contains(allergen) } }
    }

    /// Up to 12 most frequent ingredients across the menu.
    private var commonIngredients: [String] {
        var counts: [String: Int] = [:]
        for dish in dishes {
            for ingredient in dish.ingredients {
                counts[ingredient.lowercased(), default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(12).map(\.key)
    }

    private var matchCount: Int { model.filter.apply(to: dishes).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !availableTags.isEmpty { dietarySection }
                if !availableAllergens.isEmpty { allergenSection }
                spiceSection
                if !commonIngredients.isEmpty { ingredientSection }
            }
            .padding()
            .padding(.bottom, 88)
        }
        .background(Theme.page)
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Clear all") { model.clear() }
                    .disabled(!model.filter.isActive)
            }
        }
        .safeAreaInset(edge: .bottom) { showButton }
    }

    // MARK: - Sections

    private func sectionHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Spacer()
            if let trailing {
                Text(trailing).font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    private var dietarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Dietary", trailing: "\(matchCount) of \(dishes.count)")
            FlowLayout {
                ForEach(availableTags, id: \.self) { tag in
                    FilterChip(text: tag.displayName,
                               count: model.countRequiring(tag, in: dishes),
                               isSelected: model.filter.requiredTags.contains(tag)) {
                        model.toggleRequired(tag)
                    }
                }
            }
        }
    }

    private var allergenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Avoid allergens")
            FlowLayout {
                ForEach(availableAllergens, id: \.self) { allergen in
                    FilterChip(text: allergen.displayName,
                               count: model.countAvoiding(allergen, in: dishes),
                               isSelected: model.filter.avoidAllergens.contains(allergen),
                               selectedBg: Theme.alert) {
                        model.toggleAllergen(allergen)
                    }
                }
            }
        }
    }

    private var spiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Spice", trailing: model.filter.maxSpice.map { "up to \($0.displayName.lowercased())" } ?? "any")
            FlowLayout {
                FilterChip(text: "Any", count: nil, isSelected: model.filter.maxSpice == nil) {
                    model.setMaxSpice(nil)
                }
                ForEach(SpiceLevel.allCases, id: \.self) { level in
                    FilterChip(text: "\(level.displayName) \(level.chiliIndicator == "—" ? "" : level.chiliIndicator)",
                               count: model.countMaxSpice(level, in: dishes),
                               isSelected: model.filter.maxSpice == level,
                               selectedBg: Theme.accentDark) {
                        model.setMaxSpice(level)
                    }
                }
            }
        }
    }

    private var ingredientSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Ingredients")
            ForEach(commonIngredients, id: \.self) { ingredient in
                HStack {
                    Text(ingredient.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    likeDislike(for: ingredient)
                }
            }
        }
    }

    private func likeDislike(for ingredient: String) -> some View {
        HStack(spacing: 8) {
            let liked = model.filter.preferredIngredients.contains(ingredient)
            let avoided = model.filter.avoidedIngredients.contains(ingredient)

            Button {
                if liked { model.filter.preferredIngredients.remove(ingredient) }
                else {
                    model.filter.preferredIngredients.insert(ingredient)
                    model.filter.avoidedIngredients.remove(ingredient)
                }
            } label: {
                Image(systemName: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle(liked ? Theme.veg : Theme.muted)
            }

            Button {
                if avoided { model.filter.avoidedIngredients.remove(ingredient) }
                else {
                    model.filter.avoidedIngredients.insert(ingredient)
                    model.filter.preferredIngredients.remove(ingredient)
                }
            } label: {
                Image(systemName: avoided ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle(avoided ? Theme.alert : Theme.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private var showButton: some View {
        Button { dismiss() } label: {
            Text(matchCount == 0 ? "No matches" : "Show \(matchCount) matching \(matchCount == 1 ? "dish" : "dishes")")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(matchCount == 0 ? Theme.muted : Theme.accent, in: .rect(cornerRadius: Theme.Metrics.corner))
        }
        .disabled(matchCount == 0)
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    NavigationStack {
        FiltersView(model: MenuFilterModel(), dishes: ScanSession.previewLoaded.menu!.dishes)
    }
}
