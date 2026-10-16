import SwiftUI
import MiseShared

/// Filters are the mood of the meal, on top of each person's fixed profile.
struct FiltersSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var newAvoid = ""

    private let moods: [DietaryTag] = [.vegetarian, .vegan, .pescatarian, .halal, .glutenFree, .dairyFree]

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack {
                Text("Filters").font(.boardName).boardCaps().foregroundStyle(Board.onRaised)
                Spacer()
                Button("Clear") {
                    withAnimation(.smooth) {
                        model.filter = DishFilter()
                        model.hiddenSections = []
                        model.hideCrossed = false
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Board.paint)
            }
            .padding(.horizontal, Board.margin)
            .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    group("Tonight", detail: model.selectedProfile.map { "on top of \($0.name)'s profile" }) {
                        FlowLayout(spacing: 8) {
                            ForEach(moods.filter { count(adding: $0) > 0 || model.filter.requiredTags.contains($0) },
                                    id: \.self) { tag in
                                CreamChip(title: tag.displayName, detail: "\(count(adding: tag))",
                                          isOn: model.filter.requiredTags.contains(tag), showsCheck: true) {
                                    withAnimation(.snappy) { toggle(tag) }
                                }
                            }
                        }
                    }
                    group("Spice, up to") {
                        SpiceSegments(firstTitle: "Any", level: $model.filter.maxSpice)
                    }
                    priceGroup
                    HStack {
                        Text("Hide what's crossed out").font(.boardBody).foregroundStyle(Board.onRaised)
                        Spacer()
                        Toggle("", isOn: $model.hideCrossed).labelsHidden().tint(Board.paint)
                    }
                    .frame(minHeight: 44)
                    group("Also avoid") { avoidField }
                    group("Courses", detail: model.hiddenSections.isEmpty ? "all on" : nil) {
                        FlowLayout(spacing: 8) {
                            ForEach(model.menu?.sections.map(\.title) ?? [], id: \.self) { title in
                                // Outlined when on, so "all on" doesn't paint the sheet green.
                                let off = model.hiddenSections.contains(title)
                                CreamChip(title: title, isOn: false) {
                                    withAnimation(.snappy) {
                                        if off { model.hiddenSections.remove(title) } else { model.hiddenSections.insert(title) }
                                    }
                                }
                                .opacity(off ? 0.4 : 1)
                                .accessibilityValue(off ? "off" : "on")
                            }
                        }
                    }
                }
                .padding(.horizontal, Board.margin)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            BoardCTA(title: showLabel, style: .paint) { dismiss() }
                .padding(.horizontal, Board.margin)
                .padding(.bottom, 8)
                .background(alignment: .bottom) { BottomFade(color: Board.raised, height: 110).ignoresSafeArea() }
        }
        .background(Board.raised)
        .presentationDetents([.fraction(0.86), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Board.cardRadius)
        .presentationBackground(Board.raised)
        .environment(\.colorScheme, .light)
    }

    // MARK: Groups

    private func group<Content: View>(_ title: String, detail: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CreamGroupHeader(title: title, detail: detail)
            content()
        }
    }

    private var priceGroup: some View {
        let prices = (model.menu?.dishes ?? []).compactMap(\.price)
        let maxPrice = prices.max() ?? 0
        let current = model.filter.maxPrice ?? maxPrice
        let under = prices.filter { $0 <= current }.count
        let detail = [model.price(current), model.homePrice(current)].compactMap { $0 }.joined(separator: " · ")
            + " · \(under) dishes under"
        return group("Price, up to", detail: prices.isEmpty ? nil : detail) {
            Slider(value: Binding(
                get: { (current as NSDecimalNumber).doubleValue },
                set: { value in
                    let rounded = Decimal(value).rounded(0)
                    model.filter.maxPrice = rounded >= maxPrice ? nil : rounded
                }),
                in: 0...max(1, (maxPrice as NSDecimalNumber).doubleValue), step: 5)
            .tint(Board.paint)
            .frame(height: 44)
            .disabled(prices.isEmpty)
        }
    }

    private var avoidField: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            ForEach(Array(model.filter.avoidedIngredients).sorted(), id: \.self) { item in
                Button {
                    withAnimation(.snappy) { _ = model.filter.avoidedIngredients.remove(item) }
                } label: {
                    Text("\(item) ×").font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 10).frame(height: 32)
                        .overlay { Capsule().strokeBorder(Board.onRaised.opacity(0.22), lineWidth: 1.5) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop avoiding \(item)")
            }
            TextField("Add an ingredient", text: $newAvoid)
                .font(.boardSecondary)
                .submitLabel(.done)
                .onSubmit {
                    let word = newAvoid.trimmingCharacters(in: .whitespaces).lowercased()
                    if !word.isEmpty { withAnimation(.snappy) { _ = model.filter.avoidedIngredients.insert(word) } }
                    newAvoid = ""
                }
        }
        .foregroundStyle(Board.onRaised)
        .padding(.leading, 8).padding(.trailing, 12)
        .frame(height: 44)
        .background(Board.onRaised.opacity(0.06), in: .rect(cornerRadius: 10))
    }

    // MARK: Counts

    private func toggle(_ tag: DietaryTag) {
        if model.filter.requiredTags.contains(tag) {
            model.filter.requiredTags.remove(tag)
        } else {
            model.filter.requiredTags.insert(tag)
        }
    }

    /// Dishes that would still be fine (or ask) for the selected person with `tag` added.
    private func count(adding tag: DietaryTag) -> Int {
        var filter = model.filter
        filter.requiredTags.insert(tag)
        return model.visibleDishes.filter {
            Verdict.for($0, profile: model.selectedProfile, filter: filter).kind != .no
        }.count
    }

    private var showLabel: String {
        let n = model.sections(sortingFor: model.selectedProfile, sorted: false)
            .flatMap(\.dishes)
            .filter { model.verdict(for: $0, profile: model.selectedProfile).kind != .no }
            .count
        return "Show \(n) \(n == 1 ? "dish" : "dishes")"
    }
}
