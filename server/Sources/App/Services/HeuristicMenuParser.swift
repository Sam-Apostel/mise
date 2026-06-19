import Foundation
import MiseShared

/// A dependency-free parser used when no LLM is configured.
///
/// It does a best-effort split of OCR text into dishes and applies a small
/// keyword dictionary for dietary tags. Good enough to exercise the full stack
/// end-to-end without network access.
struct HeuristicMenuParser {
    func parse(text: String, hints: MenuParseHints?) -> ParsedMenu {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let dishes = lines.compactMap { line -> Dish? in
            // Skip lines that look like section headers (all caps, no price).
            if line == line.uppercased() && line.count < 24 && Self.price(in: line) == nil {
                return nil
            }
            let (name, description) = Self.splitNameAndDescription(line)
            guard !name.isEmpty else { return nil }

            return Dish(
                name: name,
                originalText: line,
                description: description,
                price: Self.price(in: line),
                currency: hints?.assumedCurrency ?? Self.currency(in: line),
                course: Self.course(for: line),
                dietaryTags: Self.tags(for: line),
                allergens: Self.allergens(for: line),
                spiceLevel: Self.spiceLevel(for: line),
                ingredients: [],
                isPopular: false,
                confidence: 0.4
            )
        }

        return ParsedMenu(currency: hints?.assumedCurrency, dishes: dishes)
    }

    private static func splitNameAndDescription(_ line: String) -> (String, String?) {
        // Many menus use "Name - description" or "Name — description".
        for separator in [" — ", " – ", " - "] {
            if let range = line.range(of: separator) {
                let name = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let desc = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                return (stripPrice(name), desc.isEmpty ? nil : stripPrice(desc))
            }
        }
        return (stripPrice(line), nil)
    }

    private static func stripPrice(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"[€$£]?\s?\d+([.,]\d{1,2})?\s?[€$£]?$"#) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        let stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return stripped.trimmingCharacters(in: CharacterSet(charactersIn: " .-—–"))
    }

    private static func price(in line: String) -> Decimal? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+[.,]\d{1,2}|\d+)"#) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, range: range)
        guard let last = matches.last, let r = Range(last.range, in: line) else { return nil }
        let raw = line[r].replacingOccurrences(of: ",", with: ".")
        return Decimal(string: raw)
    }

    private static func currency(in line: String) -> String? {
        if line.contains("€") { return "EUR" }
        if line.contains("$") { return "USD" }
        if line.contains("£") { return "GBP" }
        return nil
    }

    private static func course(for line: String) -> Course {
        let l = line.lowercased()
        if ["wine", "beer", "cocktail", "juice", "coffee", "tea", "soda"].contains(where: l.contains) { return .drink }
        if ["cake", "ice cream", "dessert", "tiramisu", "brownie", "sorbet"].contains(where: l.contains) { return .dessert }
        if ["soup", "salad", "starter", "appetizer"].contains(where: l.contains) { return .starter }
        if ["fries", "side", "bread"].contains(where: l.contains) { return .side }
        return .main
    }

    private static func tags(for line: String) -> [DietaryTag] {
        let l = line.lowercased()
        var tags: Set<DietaryTag> = []
        if ["vegan"].contains(where: l.contains) { tags.insert(.vegan); tags.insert(.vegetarian) }
        if ["vegetarian", "veggie"].contains(where: l.contains) { tags.insert(.vegetarian) }
        if ["gluten-free", "gluten free", "gf"].contains(where: l.contains) { tags.insert(.glutenFree) }
        if ["spicy", "chili", "chilli", "🌶"].contains(where: l.contains) { tags.insert(.spicy) }
        if ["pork", "bacon", "ham", "prosciutto"].contains(where: l.contains) { tags.insert(.containsPork) }
        if ["wine", "beer", "cocktail", "rum", "vodka"].contains(where: l.contains) { tags.insert(.containsAlcohol) }
        return Array(tags)
    }

    private static func allergens(for line: String) -> [Allergen] {
        let l = line.lowercased()
        var found: Set<Allergen> = []
        if ["bread", "pasta", "flour", "wheat", "noodle", "breaded", "pizza"].contains(where: l.contains) { found.insert(.gluten) }
        if ["cheese", "cream", "butter", "milk", "parmig", "mozzarella", "yoghurt"].contains(where: l.contains) { found.insert(.dairy) }
        if ["nut", "almond", "walnut", "pistachio", "hazelnut", "pesto"].contains(where: l.contains) { found.insert(.nuts) }
        if ["shrimp", "prawn", "crab", "lobster", "scampi", "shellfish"].contains(where: l.contains) { found.insert(.shellfish) }
        if ["tuna", "salmon", "cod", "anchov", "fish"].contains(where: l.contains) { found.insert(.fish) }
        if ["egg", "mayo", "carbonara"].contains(where: l.contains) { found.insert(.egg) }
        return Array(found)
    }

    private static func spiceLevel(for line: String) -> SpiceLevel {
        let l = line.lowercased()
        if ["very spicy", "extra hot", "🌶🌶🌶", "fiery"].contains(where: l.contains) { return .hot }
        if ["spicy", "chili", "chilli", "🌶", "arrabbiata", "diavola"].contains(where: l.contains) { return .medium }
        if ["mild", "lightly spiced", "a hint of heat"].contains(where: l.contains) { return .mild }
        return .none
    }
}
