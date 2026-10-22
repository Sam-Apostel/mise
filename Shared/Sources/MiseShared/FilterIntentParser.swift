import Foundation

/// Reads "only pizzas, with mozzarella and bell pepper, no mushrooms or seafood"
/// without a network: finds the menu's sections and the ingredients it knows,
/// and gives each the mood of the nearest "only" / "with" / "no" before it.
///
/// The server's model does this better; this is the offline fallback, used by
/// the app when the call fails and by the server when it has no API key.
public enum FilterIntentParser {
    private enum Mode { case want, avoid, only }

    /// Longest phrases first, so "don't want" wins over "want".
    private static let markers: [(phrase: String, mode: Mode)] = {
        let avoid = ["no", "not", "without", "avoid", "don't want", "dont want", "do not want", "don't like",
                     "do not like", "nothing with", "except", "allergic to", "geen", "zonder", "niet", "sans",
                     "pas de", "senza", "niente", "sin", "ni"]
        let want = ["with", "want", "like", "including", "extra", "met", "avec", "con", "ik wil", "je veux",
                    "voglio", "quiero"]
        let only = ["only", "just", "alleen", "enkel", "seulement", "uniquement", "solo", "solamente", "soltanto"]
        return (avoid.map { ($0, Mode.avoid) } + want.map { ($0, .want) } + only.map { ($0, .only) })
            .sorted { $0.0.count > $1.0.count }
    }()

    private static let sectionStopwords: Set<String> = [
        "and", "with", "the", "our", "from", "della", "delle", "degli", "dello", "alla", "alle", "avec", "pour",
        "house", "special", "specials", "dish", "dishes", "other", "menu"]

    public static func parse(_ text: String, sections: [String], ingredients: [String] = []) -> FilterIntent {
        let lower = " " + text.lowercased().replacingOccurrences(of: "’", with: "'") + " "
        var intent = FilterIntent()

        // Moods, longest phrase first and without overlaps.
        var marks: [(range: Range<String.Index>, mode: Mode)] = []
        for (phrase, mode) in markers {
            var start = lower.startIndex
            while let range = lower.range(of: phrase, range: start..<lower.endIndex) {
                start = range.upperBound
                if IngredientLexicon.isWordBoundary(lower, range), !marks.contains(where: { $0.range.overlaps(range) }) {
                    marks.append((range, mode))
                }
            }
        }
        func mode(before index: String.Index) -> Mode? {
            marks.filter { $0.range.upperBound <= index }.max { $0.range.lowerBound < $1.range.lowerBound }?.mode
        }

        // Ingredients: the lexicon's, then this menu's own names it does not know.
        // "mushrooms", "fish", "meat" land on names that are also families, so they cover the whole group.
        var mentions = IngredientLexicon.mentions(in: lower).map { ($0.range, $0.key.name) }
        for name in ingredients.map(IngredientLexicon.normalize) where !name.isEmpty {
            for form in [name, IngredientLexicon.plural(name)] {
                guard let range = lower.range(of: form), IngredientLexicon.isWordBoundary(lower, range),
                      !mentions.contains(where: { $0.0.overlaps(range) }) else { continue }
                mentions.append((range, name))
            }
        }
        for family in IngredientFamily.avoidable {
            for form in [family.rawValue, family.displayName.lowercased()] {
                guard let range = lower.range(of: form), IngredientLexicon.isWordBoundary(lower, range),
                      !mentions.contains(where: { $0.0.overlaps(range) }) else { continue }
                mentions.append((range, family.rawValue))
            }
        }
        for (range, item) in mentions.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
            if mode(before: range.lowerBound) == .avoid {
                intent.want.removeAll { $0 == item }
                if !intent.avoid.contains(item) { intent.avoid.append(item) }
            } else {
                intent.avoid.removeAll { $0 == item }
                if !intent.want.contains(item) { intent.want.append(item) }
            }
        }

        // Sections: "pizza" finds "Pizzas" and "Pizze".
        let words = lower.split { !$0.isLetter }.map(String.init)
        for title in sections {
            let titleWords = title.lowercased().split { !$0.isLetter }.map(String.init)
                .filter { $0.count >= 4 && !sectionStopwords.contains($0) }
            guard !titleWords.isEmpty else { continue }
            let stems = Set(titleWords.map(stem))
            guard let hit = words.firstIndex(where: { stems.contains(stem($0)) }),
                  let range = rangeOfWord(at: hit, in: lower) else { continue }
            // A section word that was also read as an ingredient is a section here.
            intent.want.removeAll { stem($0) == stem(words[hit]) }
            if mode(before: range.lowerBound) == .avoid {
                intent.hideSections.append(title)
            } else {
                intent.onlySections.append(title)
            }
        }

        // Diets, spice and price.
        let tags: [(DietaryTag, [String])] = [
            (.vegan, ["vegan", "veganistisch", "végétalien", "vegano"]),
            (.vegetarian, ["vegetarian", "veggie", "vegetarisch", "végétarien", "vegetariano"]),
            (.glutenFree, ["gluten free", "gluten-free", "glutenvrij", "sans gluten", "senza glutine", "sin gluten"]),
            (.dairyFree, ["dairy free", "dairy-free", "lactose free", "lactosevrij", "sans lactose", "senza lattosio"]),
            (.halal, ["halal"]),
        ]
        for (tag, forms) in tags where forms.contains(where: { IngredientLexicon.containsPhrase(lower, $0) }) {
            if tag == .vegetarian, intent.requiredTags.contains(.vegan) { continue }
            intent.requiredTags.append(tag)
        }
        if ["not spicy", "no spicy", "nothing spicy", "not too spicy", "niet pikant", "pas épicé", "non piccante",
            "no picante"].contains(where: { lower.contains($0) }) {
            intent.maxSpice = lower.contains("too") ? .mild : SpiceLevel.none
        } else if IngredientLexicon.containsPhrase(lower, "mild") {
            intent.maxSpice = .mild
        }
        let price = #"(under|below|less than|max|maximum|up to|at most|onder|minder dan|maximaal|moins de|sotto|meno di|menos de)\s*[€$£]?\s*(\d+(?:[.,]\d+)?)"#
        if let match = lower.range(of: price, options: .regularExpression) {
            let digits = lower[match].split { !$0.isNumber && $0 != "." && $0 != "," }.last
            intent.maxPrice = digits.flatMap { Decimal(string: $0.replacingOccurrences(of: ",", with: ".")) }
        }
        return intent
    }

    /// "pizzas" → "pizz", "pizze" → "pizz", "pizza" → "pizz".
    static func stem(_ word: String) -> String {
        var w = word.lowercased()
        if w.count > 4, w.hasSuffix("s") { w.removeLast() }
        if w.count > 3, let last = w.last, "aeiou".contains(last) { w.removeLast() }
        return w
    }

    private static func rangeOfWord(at index: Int, in text: String) -> Range<String.Index>? {
        var count = -1
        var start: String.Index?
        var i = text.startIndex
        while i < text.endIndex {
            let letter = text[i].isLetter
            if letter, start == nil { start = i; count += 1 }
            if !letter, let s = start {
                if count == index { return s..<i }
                start = nil
            }
            i = text.index(after: i)
        }
        if let start, count == index { return start..<text.endIndex }
        return nil
    }
}

extension FilterIntent {
    /// Applies the intent to tonight's filter and the section switches.
    /// `allSections` are the menu's titles; "only" hides every other one.
    public func apply(to filter: inout DishFilter, hiddenSections: inout Set<String>, allSections: [String]) {
        filter.preferredIngredients.formUnion(want)
        filter.preferredIngredients.subtract(avoid)
        filter.avoidedIngredients.formUnion(avoid)
        filter.avoidedIngredients.subtract(want)
        filter.requiredTags.formUnion(requiredTags)
        if let maxSpice { filter.maxSpice = maxSpice }
        if let maxPrice { filter.maxPrice = maxPrice }
        if !onlySections.isEmpty {
            hiddenSections = Set(allSections.filter { !onlySections.contains($0) })
        }
        hiddenSections.formUnion(hideSections)
    }
}
