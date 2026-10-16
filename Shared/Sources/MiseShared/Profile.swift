import Foundation

/// One person at the table, with what they cannot or will not eat.
///
/// Profiles live on the device; the server never sees them. The verdict for a
/// dish is computed from a profile with `Verdict.for(_:profile:filter:)`.
public struct Profile: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// Allergens this person reacts to. A dish containing one is "no";
    /// a dish that probably contains one is "ask".
    public var allergens: Set<Allergen>
    /// Things this person does not eat but is not allergic to ("pork", "alcohol").
    /// Matched against the dish's tags, protein and ingredients.
    public var avoids: [String]
    /// The hottest dish this person eats. `.hot` means any.
    public var maxSpice: SpiceLevel
    /// Put the allergy sentence on the waiter card.
    public var severe: Bool
    /// Grammatical gender for languages that need one in "I am allergic"
    /// (Italian "allergica" / "allergico", Thai ค่ะ / ครับ).
    public var speech: Speech

    public enum Speech: String, Codable, CaseIterable, Sendable {
        case feminine, masculine, neutral
    }

    public init(
        id: UUID = UUID(),
        name: String,
        allergens: Set<Allergen> = [],
        avoids: [String] = [],
        maxSpice: SpiceLevel = .hot,
        severe: Bool = false,
        speech: Speech = .neutral
    ) {
        self.id = id
        self.name = name
        self.allergens = allergens
        self.avoids = avoids
        self.maxSpice = maxSpice
        self.severe = severe
        self.speech = speech
    }

    /// The initial shown in avatars and on the waiter card.
    public var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }

    /// The "Avoids" options offered in the People sheet, before "+ other".
    public static let commonAvoids = ["pork", "beef", "alcohol"]
}

/// What a dish means for one person: fine, ask first, or not for them.
public struct Verdict: Hashable, Sendable {
    public enum Kind: Int, Comparable, Sendable, CaseIterable {
        case fine = 0, ask = 1, no = 2
        public static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
    }

    public enum Cause: Hashable, Sendable {
        case allergen
        case avoid
        case spice(dish: SpiceLevel, max: SpiceLevel)
        case filter
        case likely(LikelyIngredient)
    }

    public var kind: Kind
    /// Short reason for the tile ("Peanuts, dried shrimp", "Hot", "Shrimp paste? Ask.").
    public var reason: String?
    public var cause: Cause?

    public static let fine = Verdict(kind: .fine, reason: nil, cause: nil)

    public init(kind: Kind, reason: String?, cause: Cause?) {
        self.kind = kind
        self.reason = reason
        self.cause = cause
    }

    /// The verdict for `dish` and `profile`, with tonight's `filter` on top.
    ///
    /// Order of precedence: a listed allergen, an avoided food, a spice above
    /// the person's cap, a failed filter, then a likely-but-unlisted ingredient.
    /// With no profile (the "Everyone" view) only the filter applies.
    public static func `for`(_ dish: Dish, profile: Profile?, filter: DishFilter = DishFilter()) -> Verdict {
        if let profile {
            let hits = dish.allergens.filter(profile.allergens.contains)
            if !hits.isEmpty {
                let sources = dish.allergenSources
                    .filter { profile.allergens.contains($0.allergen) }
                    .map(\.ingredient)
                let words = sources.isEmpty ? hits.map { $0.displayName.lowercased() } : sources
                return Verdict(kind: .no, reason: unique(words).joined(separator: ", ").capitalizedFirst,
                               cause: .allergen)
            }
            let avoided = profile.avoids.filter { dish.contains(avoid: $0) }
            if !avoided.isEmpty {
                return Verdict(kind: .no, reason: listSentence(avoided), cause: .avoid)
            }
            if dish.spiceLevel > profile.maxSpice {
                return Verdict(kind: .no, reason: dish.spiceLevel.displayName,
                               cause: .spice(dish: dish.spiceLevel, max: profile.maxSpice))
            }
        }
        if filter.isActive, !filter.matches(dish) {
            return Verdict(kind: .no, reason: filter.reason(failing: dish), cause: .filter)
        }
        for likely in dish.likelyIngredients {
            let allergenHit = profile.map { !$0.allergens.isDisjoint(with: likely.allergens) } ?? false
            let avoidHit = profile?.avoids.contains { likely.name.localizedCaseInsensitiveContains($0) } ?? false
            let filterHit = !filter.requiredTags.isDisjoint(with: likely.breaks)
            if allergenHit || avoidHit || filterHit {
                let line = likely.note.map { "\($0). Ask." } ?? "\(likely.name.capitalizedFirst)? Ask."
                return Verdict(kind: .ask, reason: line, cause: .likely(likely))
            }
        }
        return .fine
    }
}

extension Dish {
    /// Whether the dish contains something a person avoids ("pork", "alcohol", "coriander").
    public func contains(avoid: String) -> Bool {
        let word = avoid.lowercased().trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return false }
        switch word {
        case "pork": if dietaryTags.contains(.containsPork) { return true }
        case "alcohol": if dietaryTags.contains(.containsAlcohol) { return true }
        default: break
        }
        let haystack = ([protein ?? ""] + ingredients).map { $0.lowercased() }
        return haystack.contains { $0.contains(word) }
    }
}

extension DishFilter {
    /// Why `dish` fails this filter, in a few words for the tile.
    public func reason(failing dish: Dish) -> String {
        let missing = requiredTags.subtracting(dish.dietaryTags)
        if !missing.isEmpty {
            if let protein = dish.protein { return protein.capitalizedFirst }
            if missing.contains(.vegetarian) { return "Not vegetarian" }
            if missing.contains(.vegan) { return "Not vegan" }
            return "Not \(missing.map { $0.displayName.lowercased() }.sorted().joined(separator: ", "))"
        }
        if !avoidAllergens.isDisjoint(with: dish.allergens) {
            return listSentence(dish.allergens.filter(avoidAllergens.contains).map(\.displayName))
        }
        if let maxSpice, dish.spiceLevel > maxSpice { return dish.spiceLevel.displayName }
        if let maxPrice, let price = dish.price, price > maxPrice { return "Over budget" }
        let avoided = avoidedIngredients.filter { dish.contains(avoid: $0) }
        if !avoided.isEmpty { return listSentence(Array(avoided).sorted()) }
        return "Filtered out"
    }
}

/// "a" · "a and b" · "a, b and c", first letter capitalised.
func listSentence(_ words: [String]) -> String {
    let list: String
    switch words.count {
    case 0: list = ""
    case 1: list = words[0]
    default: list = words.dropLast().joined(separator: ", ") + " and " + words.last!
    }
    return list.capitalizedFirst
}

private func unique(_ words: [String]) -> [String] {
    var seen = Set<String>()
    return words.filter { seen.insert($0.lowercased()).inserted }
}

extension String {
    /// The string with only its first character uppercased ("dried shrimp" → "Dried shrimp").
    public var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
