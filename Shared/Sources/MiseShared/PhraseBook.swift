import Foundation

/// The words on the waiter card, in the menu's language.
public struct PhraseSet: Codable, Hashable, Sendable {
    /// BCP-47 code the phrases are in.
    public var language: String
    /// "ขอสั่ง" / "Vorrei": leads the order.
    public var order: String
    /// "ขอบคุณค่ะ" / "Grazie".
    public var thanks: String
    /// The allergy sentence as one or two lines ("แพ้ถั่วลิสง กุ้ง และปู", "ไม่ใส่ถั่ว กุ้ง ปู").
    /// Empty when the person has no allergens.
    public var allergy: [String]
    /// The allergy sentence in English, shown small under it.
    public var allergyTranslation: String?

    public init(language: String, order: String, thanks: String, allergy: [String], allergyTranslation: String?) {
        self.language = language
        self.order = order
        self.thanks = thanks
        self.allergy = allergy
        self.allergyTranslation = allergyTranslation
    }
}

/// Built-in, offline phrases for the languages Mise is used in first.
///
/// Thai and Italian are written out by hand (the two trips); English is the
/// fallback. The server answers other languages through the model.
public enum PhraseBook {
    public static let languages: Set<String> = ["th", "it", "en"]

    /// Phrases for `allergens` in `language`, or `nil` when the language is not built in.
    public static func phrases(
        language: String,
        allergens: Set<Allergen>,
        speech: Profile.Speech = .neutral
    ) -> PhraseSet? {
        let lang = String(language.lowercased().prefix(2))
        let ordered = Allergen.allCases.filter(allergens.contains)
        let english = englishSentence(ordered)
        switch lang {
        case "th":
            return PhraseSet(
                language: "th", order: "ขอสั่ง",
                thanks: speech == .masculine ? "ขอบคุณครับ" : "ขอบคุณค่ะ",
                allergy: thaiLines(ordered), allergyTranslation: english)
        case "it":
            return PhraseSet(
                language: "it", order: "Vorrei",
                thanks: "Grazie",
                allergy: italianLines(ordered, speech: speech), allergyTranslation: english)
        case "en":
            return PhraseSet(
                language: "en", order: "I'd like",
                thanks: "Thank you",
                allergy: english.map { [$0] } ?? [], allergyTranslation: nil)
        default:
            return nil
        }
    }

    // MARK: - English

    static func englishWords(_ allergen: Allergen) -> [String] {
        switch allergen {
        case .peanuts: return ["peanuts"]
        case .nuts: return ["tree nuts"]
        case .shellfish: return ["shrimp", "crab"]
        case .fish: return ["fish"]
        case .egg: return ["egg"]
        case .dairy: return ["dairy"]
        case .gluten: return ["gluten"]
        case .soy: return ["soy"]
        case .sesame: return ["sesame"]
        }
    }

    static func englishSentence(_ allergens: [Allergen]) -> String? {
        let words = allergens.flatMap(englishWords)
        guard !words.isEmpty else { return nil }
        let none = words.count == 1 ? "None, please." : "None of them, please."
        return "Allergic to \(join(words, last: " and ")). \(none)"
    }

    // MARK: - Thai

    /// (allergic-to word(s), short word(s) for "without …").
    static func thaiWords(_ allergen: Allergen) -> (full: [String], short: [String]) {
        switch allergen {
        case .peanuts: return (["ถั่วลิสง"], ["ถั่ว"])
        case .nuts: return (["ถั่วเปลือกแข็ง"], ["ถั่ว"])
        case .shellfish: return (["กุ้ง", "ปู"], ["กุ้ง", "ปู"])
        case .fish: return (["ปลา"], ["ปลา"])
        case .egg: return (["ไข่"], ["ไข่"])
        case .dairy: return (["นมวัว"], ["นม"])
        case .gluten: return (["แป้งสาลี"], ["แป้งสาลี"])
        case .soy: return (["ถั่วเหลือง"], ["ถั่วเหลือง"])
        case .sesame: return (["งา"], ["งา"])
        }
    }

    static func thaiLines(_ allergens: [Allergen]) -> [String] {
        guard !allergens.isEmpty else { return [] }
        let full = allergens.flatMap { thaiWords($0).full }
        var short: [String] = []
        for word in allergens.flatMap({ thaiWords($0).short }) where !short.contains(word) {
            short.append(word)
        }
        // Thai separates list items with spaces and puts และ ("and") straight onto the last one.
        let allergic = full.count == 1 ? full[0] : full.dropLast().joined(separator: " ") + " และ" + full.last!
        return ["แพ้" + allergic, "ไม่ใส่" + short.joined(separator: " ")]
    }

    // MARK: - Italian

    /// The noun with its article after "a" ("alle arachidi"), plus examples.
    static func italianPhrase(_ allergen: Allergen) -> (phrase: String, examples: String?) {
        switch allergen {
        case .peanuts: return ("alle arachidi", nil)
        case .nuts: return ("alla frutta a guscio", nil)
        case .shellfish: return ("ai crostacei", "gamberi, granchio")
        case .fish: return ("al pesce", nil)
        case .egg: return ("alle uova", nil)
        case .dairy: return ("ai latticini", nil)
        case .gluten: return ("al glutine", nil)
        case .soy: return ("alla soia", nil)
        case .sesame: return ("al sesamo", nil)
        }
    }

    static func italianLines(_ allergens: [Allergen], speech: Profile.Speech) -> [String] {
        guard !allergens.isEmpty else { return [] }
        let parts = allergens.map(italianPhrase)
        let lead: String
        switch speech {
        case .feminine: lead = "Sono allergica"
        case .masculine: lead = "Sono allergico"
        case .neutral: lead = "Ho un'allergia"
        }
        let examples = parts.compactMap(\.examples).joined(separator: ", ")
        let tail = examples.isEmpty ? "." : ": \(examples)."
        return ["\(lead) \(join(parts.map(\.phrase), last: " e "))\(tail)"]
    }

    // MARK: -

    static func join(_ words: [String], last: String) -> String {
        guard words.count > 1 else { return words.first ?? "" }
        return words.dropLast().joined(separator: ", ") + last + words.last!
    }
}
