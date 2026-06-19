import SwiftUI
import MiseShared

/// Frame 07 — "Nothing fits all of that". Names the culprit constraint and offers
/// one-tap ways to loosen the filter.
struct EmptyMatchesView: View {
    @Bindable var model: MenuFilterModel
    let dishes: [Dish]

    private var suggestions: [MenuFilterModel.Suggestion] { model.loosenSuggestions(for: dishes) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 40)
                    .overlay(
                        Circle().strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 120, height: 120)
                            .padding(.top, 40)
                    )

                Text("Nothing fits all of that")
                    .font(.serifTitle(22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("0 of \(dishes.count) dishes match. One filter is doing most of the damage:")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let top = suggestions.first {
                    culpritCard(top)
                }

                if suggestions.count > 1 {
                    VStack(spacing: 10) {
                        Text("or loosen one:")
                            .font(.footnote)
                            .foregroundStyle(Theme.muted)
                        FlowLayout {
                            ForEach(suggestions.dropFirst()) { suggestion in
                                Button { suggestion.apply() } label: {
                                    Text("\(suggestion.label) · \(suggestion.resultCount)")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.inkSoft)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Button("Clear all filters") { model.clear() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.accentDark)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
        .background(Theme.page)
    }

    private func culpritCard(_ suggestion: MenuFilterModel.Suggestion) -> some View {
        VStack(spacing: 12) {
            Text("This one rules out the most dishes.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accentDark)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { suggestion.apply() } label: {
                Text("\(suggestion.label.capitalizedFirst) → \(suggestion.resultCount) \(suggestion.resultCount == 1 ? "dish" : "dishes")")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent, in: .rect(cornerRadius: Theme.Metrics.corner))
            }
        }
        .padding()
        .background(Theme.accentTint, in: .rect(cornerRadius: Theme.Metrics.corner))
        .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.corner).stroke(Theme.accent, lineWidth: 1.5))
        .padding(.horizontal)
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

#Preview {
    let model = MenuFilterModel()
    model.filter.requiredTags = [.vegan]
    model.filter.avoidAllergens = [.dairy]
    model.filter.maxSpice = SpiceLevel.none
    return EmptyMatchesView(model: model, dishes: ScanSession.previewLoaded.menu!.dishes)
}
