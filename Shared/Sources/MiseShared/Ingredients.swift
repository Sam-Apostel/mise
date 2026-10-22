import Foundation

/// The broad group an ingredient belongs to, so "no seafood" or "no mushrooms"
/// can cross out tuna, prawns and porcini without listing each one.
public enum IngredientFamily: String, Codable, CaseIterable, Sendable {
    case meat
    case seafood
    case cheese
    case mushroom
    case egg
    case nuts
    case vegetable
    case herb
    case other

    /// Shown on the chip ("Seafood", "Mushrooms").
    public var displayName: String {
        switch self {
        case .meat: "Meat"
        case .seafood: "Seafood"
        case .cheese: "Cheese"
        case .mushroom: "Mushrooms"
        case .egg: "Egg"
        case .nuts: "Nuts"
        case .vegetable: "Vegetables"
        case .herb: "Herbs"
        case .other: "Other"
        }
    }

    /// Families a diner plausibly wants to avoid as a whole; these get their own chips.
    public static let avoidable: [IngredientFamily] = [.meat, .seafood, .cheese, .mushroom, .egg, .nuts]
}

/// One ingredient under its standard English name ("funghi" → "mushroom").
public struct IngredientKey: Codable, Hashable, Sendable {
    /// Lowercase, singular English ("mushroom", "bell pepper", "mozzarella").
    public var name: String
    public var family: IngredientFamily

    public init(name: String, family: IngredientFamily) {
        self.name = name
        self.family = family
    }

    private enum CodingKeys: String, CodingKey { case name, family }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name).lowercased()
        family = (try? c.decodeIfPresent(IngredientFamily.self, forKey: .family)) ?? .other
    }
}

/// A small offline dictionary of common menu ingredients in Italian, French,
/// Spanish, Dutch and English. It covers menus parsed before the parser
/// returned `Dish.ingredientKeys`, and the offline sentence parser.
public enum IngredientLexicon {
    struct Entry {
        let name: String
        let family: IngredientFamily
        let synonyms: [String]
    }

    static let entries: [Entry] = [
        // Mushrooms
        .init(name: "mushroom", family: .mushroom, synonyms: [
            "mushroom", "funghi", "fungo", "funghi champignon", "champignon", "champignons", "champignons de paris",
            "chiodini", "shiitake", "portobello", "pleurotes", "setas", "champiñones", "champiñón", "paddenstoelen"]),
        .init(name: "porcini", family: .mushroom, synonyms: ["porcini", "porcino", "funghi porcini", "cèpes", "cèpe", "boletus"]),
        .init(name: "truffle", family: .mushroom, synonyms: ["truffle", "tartufo", "truffe", "trufa", "truffel"]),
        // Seafood
        .init(name: "prawn", family: .seafood, synonyms: [
            "prawn", "shrimp", "gamberi", "gamberetti", "gambero", "gamberoni", "scampi", "crevette", "crevettes",
            "gambas", "gamba", "langostinos", "garnalen", "garnaal"]),
        .init(name: "tuna", family: .seafood, synonyms: ["tuna", "tonno", "thon", "atún", "atun", "tonijn"]),
        .init(name: "anchovy", family: .seafood, synonyms: [
            "anchovy", "anchovies", "acciughe", "acciuga", "alici", "anchois", "anchoas", "boquerones", "ansjovis"]),
        .init(name: "mussel", family: .seafood, synonyms: ["mussel", "cozze", "moules", "mejillones", "mosselen"]),
        .init(name: "clam", family: .seafood, synonyms: ["clam", "vongole", "palourdes", "almejas"]),
        .init(name: "squid", family: .seafood, synonyms: ["squid", "calamari", "calamaro", "calamares", "calamar", "encornet", "inktvis"]),
        .init(name: "octopus", family: .seafood, synonyms: ["octopus", "polpo", "poulpe", "pulpo"]),
        .init(name: "salmon", family: .seafood, synonyms: ["salmon", "salmone", "saumon", "salmón", "zalm"]),
        .init(name: "seafood", family: .seafood, synonyms: [
            "seafood", "frutti di mare", "fruits de mer", "mariscos", "zeevruchten", "fish", "pesce", "poisson",
            "pescado", "vis"]),
        .init(name: "crab", family: .seafood, synonyms: ["crab", "granchio", "crabe", "cangrejo", "krab"]),
        .init(name: "lobster", family: .seafood, synonyms: ["lobster", "aragosta", "astice", "homard", "langosta", "kreeft"]),
        .init(name: "cod", family: .seafood, synonyms: ["cod", "baccalà", "baccala", "merluzzo", "cabillaud", "bacalao", "kabeljauw"]),
        .init(name: "swordfish", family: .seafood, synonyms: ["swordfish", "pesce spada", "espadon", "pez espada"]),
        .init(name: "sardine", family: .seafood, synonyms: ["sardine", "sarde", "sardines", "sardinas"]),
        // Cheese
        .init(name: "mozzarella", family: .cheese, synonyms: [
            "mozzarella", "fior di latte", "mozzarella di bufala", "bufala", "buffalo mozzarella", "mozzarella fior di latte"]),
        .init(name: "gorgonzola", family: .cheese, synonyms: ["gorgonzola", "dolcelatte"]),
        .init(name: "parmesan", family: .cheese, synonyms: [
            "parmesan", "parmigiano", "parmigiano reggiano", "grana", "grana padano", "parmezaan"]),
        .init(name: "pecorino", family: .cheese, synonyms: ["pecorino", "pecorino romano"]),
        .init(name: "ricotta", family: .cheese, synonyms: ["ricotta"]),
        .init(name: "burrata", family: .cheese, synonyms: ["burrata"]),
        .init(name: "stracciatella", family: .cheese, synonyms: ["stracciatella"]),
        .init(name: "provola", family: .cheese, synonyms: ["provola", "provola affumicata", "provolone", "scamorza"]),
        .init(name: "fontina", family: .cheese, synonyms: ["fontina"]),
        .init(name: "taleggio", family: .cheese, synonyms: ["taleggio"]),
        .init(name: "goat cheese", family: .cheese, synonyms: [
            "goat cheese", "goat's cheese", "caprino", "chèvre", "fromage de chèvre", "queso de cabra", "geitenkaas"]),
        .init(name: "feta", family: .cheese, synonyms: ["feta"]),
        .init(name: "emmental", family: .cheese, synonyms: ["emmental", "emmentaler"]),
        .init(name: "cheese", family: .cheese, synonyms: ["cheese", "formaggio", "formaggi", "fromage", "queso", "kaas"]),
        // Meat
        .init(name: "ham", family: .meat, synonyms: [
            "ham", "prosciutto cotto", "cotto", "jambon", "jambon blanc", "jamón york", "jamon york", "gekookte ham"]),
        .init(name: "prosciutto", family: .meat, synonyms: [
            "prosciutto", "prosciutto crudo", "crudo", "parma ham", "prosciutto di parma", "jambon cru",
            "jamón serrano", "jamon serrano", "rauwe ham"]),
        .init(name: "salami", family: .meat, synonyms: [
            "salami", "salame", "pepperoni", "salamino", "salamino piccante", "salame piccante", "spianata"]),
        .init(name: "sausage", family: .meat, synonyms: ["sausage", "salsiccia", "saucisse", "salchicha", "worst"]),
        .init(name: "bacon", family: .meat, synonyms: ["bacon", "pancetta", "guanciale", "lardons", "lardo", "spek"]),
        .init(name: "speck", family: .meat, synonyms: ["speck"]),
        .init(name: "nduja", family: .meat, synonyms: ["nduja", "'nduja"]),
        .init(name: "bresaola", family: .meat, synonyms: ["bresaola"]),
        .init(name: "mortadella", family: .meat, synonyms: ["mortadella"]),
        .init(name: "chorizo", family: .meat, synonyms: ["chorizo"]),
        .init(name: "chicken", family: .meat, synonyms: ["chicken", "pollo", "poulet", "kip"]),
        .init(name: "beef", family: .meat, synonyms: ["beef", "manzo", "bœuf", "boeuf", "ternera", "rundvlees", "rund"]),
        .init(name: "pork", family: .meat, synonyms: ["pork", "maiale", "porc", "cerdo", "varkensvlees", "varken"]),
        .init(name: "lamb", family: .meat, synonyms: ["lamb", "agnello", "agneau", "cordero", "lam"]),
        .init(name: "kebab", family: .meat, synonyms: ["kebab", "döner", "doner", "kebap"]),
        .init(name: "meatball", family: .meat, synonyms: ["meatball", "polpette", "polpettine", "boulettes", "albóndigas", "gehaktballetjes"]),
        .init(name: "meat", family: .meat, synonyms: ["meat", "carne", "viande", "vlees"]),
        // Vegetables
        .init(name: "bell pepper", family: .vegetable, synonyms: [
            "bell pepper", "sweet pepper", "red pepper", "peppers", "peperoni", "peperone", "peperoncini dolci",
            "poivron", "poivrons", "pimiento", "pimientos", "pimiento rojo"]),
        .init(name: "chilli", family: .vegetable, synonyms: [
            "chilli", "chili", "chile", "peperoncino", "piment", "guindilla", "jalapeño", "jalapeno"]),
        .init(name: "onion", family: .vegetable, synonyms: [
            "onion", "cipolla", "cipolle", "cipolla rossa", "red onion", "oignon", "oignons", "cebolla", "ui", "uien"]),
        .init(name: "garlic", family: .vegetable, synonyms: ["garlic", "aglio", "ail", "ajo", "knoflook"]),
        .init(name: "tomato", family: .vegetable, synonyms: [
            "tomato", "pomodoro", "pomodori", "pomodorini", "cherry tomato", "datterini", "pomodoro san marzano",
            "san marzano", "tomate", "tomates", "tomaat", "tomaten", "tomato sauce", "salsa di pomodoro"]),
        .init(name: "aubergine", family: .vegetable, synonyms: [
            "aubergine", "eggplant", "melanzane", "melanzana", "berenjena", "aubergines"]),
        .init(name: "courgette", family: .vegetable, synonyms: [
            "courgette", "zucchini", "zucchine", "zucchina", "calabacín", "calabacin"]),
        .init(name: "spinach", family: .vegetable, synonyms: ["spinach", "spinaci", "épinards", "epinards", "espinacas", "spinazie"]),
        .init(name: "artichoke", family: .vegetable, synonyms: [
            "artichoke", "carciofi", "carciofo", "carciofini", "artichaut", "artichauts", "alcachofa", "alcachofas", "artisjok"]),
        .init(name: "olive", family: .vegetable, synonyms: [
            "olive", "olive nere", "olive verdi", "olive taggiasche", "olives", "aceitunas", "olijven"]),
        .init(name: "rocket", family: .vegetable, synonyms: ["rocket", "arugula", "rucola", "rughetta", "roquette", "rúcula", "rucula"]),
        .init(name: "potato", family: .vegetable, synonyms: ["potato", "patate", "patata", "pommes de terre", "aardappel", "aardappelen"]),
        .init(name: "sweetcorn", family: .vegetable, synonyms: ["sweetcorn", "corn", "mais", "maïs", "maíz"]),
        .init(name: "caper", family: .vegetable, synonyms: ["caper", "capperi", "câpres", "alcaparras", "kappertjes"]),
        .init(name: "broccoli", family: .vegetable, synonyms: ["broccoli", "brocoli", "friarielli", "cime di rapa", "broccoli rabe"]),
        .init(name: "pineapple", family: .vegetable, synonyms: ["pineapple", "ananas", "piña"]),
        // Herbs
        .init(name: "basil", family: .herb, synonyms: ["basil", "basilico", "basilic", "albahaca", "basilicum"]),
        .init(name: "oregano", family: .herb, synonyms: ["oregano", "origano", "origan", "orégano"]),
        // Egg and nuts
        .init(name: "egg", family: .egg, synonyms: ["egg", "uovo", "uova", "œuf", "oeuf", "œufs", "huevo", "huevos", "ei", "eieren"]),
        .init(name: "pistachio", family: .nuts, synonyms: ["pistachio", "pistacchio", "pistacchi", "pistache", "pistacho"]),
        .init(name: "walnut", family: .nuts, synonyms: ["walnut", "noci", "noce", "noix", "nueces", "walnoten"]),
        .init(name: "pine nut", family: .nuts, synonyms: ["pine nut", "pinoli", "pignons", "piñones"]),
        .init(name: "hazelnut", family: .nuts, synonyms: ["hazelnut", "nocciole", "nocciola", "noisettes", "avellanas"]),
        .init(name: "almond", family: .nuts, synonyms: ["almond", "mandorle", "mandorla", "amandes", "almendras", "amandelen"]),
    ]

    /// Synonym → entry, longest synonyms first so "prosciutto cotto" beats "prosciutto".
    static let index: [(synonym: String, entry: Entry)] = {
        var pairs: [(String, Entry)] = []
        for entry in entries {
            pairs.append((entry.name, entry))
            for synonym in entry.synonyms { pairs.append((normalize(synonym), entry)) }
        }
        return pairs.sorted { $0.0.count > $1.0.count }
    }()

    private static let exact: [String: Entry] = {
        var map: [String: Entry] = [:]
        for (synonym, entry) in index where map[synonym] == nil { map[synonym] = entry }
        return map
    }()

    /// Lookups are cached: the board asks for every dish's keys on each render.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var memo: [String: IngredientKey] = [:]

    /// The key for one listed ingredient ("Funghi champignon" → mushroom).
    /// Unknown ingredients keep their own name, made singular, in `.other`.
    public static func key(for ingredient: String) -> IngredientKey {
        if let hit = lock.withLock({ memo[ingredient] }) { return hit }
        let key = lookUp(ingredient)
        lock.withLock { memo[ingredient] = key }
        return key
    }

    private static func lookUp(_ ingredient: String) -> IngredientKey {
        let word = normalize(ingredient)
        if let entry = exact[word] ?? exact[singular(word)] {
            return IngredientKey(name: entry.name, family: entry.family)
        }
        // "mozzarella di bufala campana" → mozzarella: the longest known phrase inside it.
        if let hit = index.first(where: { containsPhrase(word, $0.synonym) }) {
            return IngredientKey(name: hit.entry.name, family: hit.entry.family)
        }
        return IngredientKey(name: singular(word), family: .other)
    }

    /// Every known ingredient named in `text`, with where it starts, longest match
    /// first and without overlaps. Used by the offline sentence parser.
    static func mentions(in text: String) -> [(range: Range<String.Index>, key: IngredientKey)] {
        var found: [(Range<String.Index>, IngredientKey)] = []
        for (synonym, entry) in index {
            for form in [synonym, plural(synonym)] {
                var start = text.startIndex
                while let range = text.range(of: form, range: start..<text.endIndex) {
                    start = range.upperBound
                    guard isWordBoundary(text, range),
                          !found.contains(where: { $0.0.overlaps(range) }) else { continue }
                    found.append((range, IngredientKey(name: entry.name, family: entry.family)))
                }
            }
        }
        return found.sorted { $0.0.lowerBound < $1.0.lowerBound }
    }

    // MARK: Text helpers

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// "mushrooms" → "mushroom", "tomatoes" → "tomato", "anchovies" → "anchovy".
    static func singular(_ word: String) -> String {
        guard word.count > 3, !word.hasSuffix("ss"), !word.hasSuffix("us") else { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("s") { return String(word.dropLast()) }
        return word
    }

    static func plural(_ word: String) -> String {
        if word.hasSuffix("y"), !word.hasSuffix("ey") { return String(word.dropLast()) + "ies" }
        if word.hasSuffix("o") { return word + "es" }
        if word.hasSuffix("s") { return word }
        return word + "s"
    }

    static func containsPhrase(_ text: String, _ phrase: String) -> Bool {
        guard let range = text.range(of: phrase) else { return false }
        return isWordBoundary(text, range)
    }

    static func isWordBoundary(_ text: String, _ range: Range<String.Index>) -> Bool {
        let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
        let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
        return !(before?.isLetter ?? false) && !(after?.isLetter ?? false)
    }
}

extension Dish {
    /// The dish's ingredients under their standard names: the parser's own keys
    /// when it gave them, else looked up offline from `ingredients`.
    public var keys: [IngredientKey] {
        var keys = ingredientKeys.isEmpty ? ingredients.map(IngredientLexicon.key(for:)) : ingredientKeys
        if let protein, ingredientKeys.isEmpty {
            keys += IngredientLexicon.mentions(in: IngredientLexicon.normalize(protein)).map(\.key)
        }
        var seen = Set<String>()
        return keys.filter { seen.insert($0.name).inserted }
    }

    /// Whether the dish has `item`: a standard name ("mushroom"), a family
    /// ("seafood"), or any word a person typed ("funghi", "coriander").
    public func has(_ item: String) -> Bool {
        let word = IngredientLexicon.normalize(item)
        guard !word.isEmpty else { return false }
        let keys = self.keys
        if let family = IngredientFamily(rawValue: word) ?? IngredientFamily(rawValue: IngredientLexicon.singular(word))
            ?? IngredientFamily.allCases.first(where: { $0.displayName.lowercased() == word }) {
            if keys.contains(where: { $0.family == family }) { return true }
            switch family {
            case .seafood: if allergens.contains(.fish) || allergens.contains(.shellfish) { return true }
            case .egg: if allergens.contains(.egg) { return true }
            case .nuts: if allergens.contains(.nuts) || allergens.contains(.peanuts) { return true }
            case .meat: if dietaryTags.contains(.containsPork) { return true }
            default: break
            }
            if family != .other, family != .vegetable, family != .herb { return false }
        }
        let canonical = IngredientLexicon.key(for: word).name
        if keys.contains(where: { $0.name == canonical }) { return true }
        // A typed word the lexicon does not know: look for it in the menu's own words.
        let haystack = ([protein ?? ""] + ingredients + keys.map(\.name)).map(IngredientLexicon.normalize)
        return haystack.contains { IngredientLexicon.containsPhrase($0, word) || IngredientLexicon.containsPhrase($0, canonical) }
    }
}

/// How often each ingredient and family turns up across a set of dishes,
/// for the "On this menu" chips.
public struct IngredientIndex: Sendable {
    public struct Item: Hashable, Sendable {
        public var key: IngredientKey
        public var count: Int
    }

    public struct FamilyItem: Hashable, Sendable {
        public var family: IngredientFamily
        public var count: Int
    }

    public var ingredients: [Item]
    public var families: [FamilyItem]

    public init(dishes: [Dish]) {
        var counts: [IngredientKey: Int] = [:]
        var firstSeen: [IngredientKey: Int] = [:]
        for dish in dishes {
            for key in dish.keys {
                counts[key, default: 0] += 1
                if firstSeen[key] == nil { firstSeen[key] = firstSeen.count }
            }
        }
        ingredients = counts.map { Item(key: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : firstSeen[$0.key]! < firstSeen[$1.key]! }
        families = IngredientFamily.avoidable.compactMap { family in
            let n = dishes.filter { $0.has(family.rawValue) }.count
            return n > 0 ? FamilyItem(family: family, count: n) : nil
        }
    }
}
