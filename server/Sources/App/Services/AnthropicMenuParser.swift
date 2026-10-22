import Vapor
import MiseShared

/// Parses + enriches menu text with the Anthropic Messages API.
///
/// Uses structured outputs (see `AnthropicStructuredCall`) so the model returns
/// JSON matching `schema`, which `LLMMenu` then maps onto the shared DTOs.
struct AnthropicMenuParser {
    let apiKey: String
    let model: String

    func parse(
        text: String,
        hints: MenuParseHints?,
        client: any Client,
        logger: Logger
    ) async throws -> ParsedMenu {
        let data = try await AnthropicStructuredCall(apiKey: apiKey, model: model).run(
            system: Self.systemPrompt(hints: hints),
            user: text,
            schema: Self.schema,
            maxTokens: 16000,
            client: client
        )
        return try Self.decodeMenu(data, defaultCurrency: hints?.assumedCurrency)
    }

    /// Maps the model's JSON onto a `ParsedMenu`. Pure, so tests can run it without network.
    static func decodeMenu(_ data: Data, defaultCurrency: String?) throws -> ParsedMenu {
        try JSONDecoder().decode(LLMMenu.self, from: data).toParsedMenu(defaultCurrency: defaultCurrency)
    }

    static func systemPrompt(hints: MenuParseHints?) -> String {
        let language = hints?.preferredLanguage ?? "en"
        return """
        You convert raw OCR text from a restaurant menu into structured data for a traveller \
        who cannot read the menu's language and may have food allergies.
        Extract every dish. Do not invent dishes that are not in the text.

        For the menu:
        - `restaurantName`: in language "\(language)" (transliterated if needed), or null.
        - `originalRestaurantName`: the name as printed in the menu's own script, or null when \
        it is the same as `restaurantName`.
        - `cuisine`: the cuisine in language "\(language)" ("Thai", "Italian"), or null.
        - `sourceLanguage`: BCP-47 code of the menu's language.
        - `currency`: ISO 4217 code when it can be told.

        For each dish:
        - `name`: translated into language "\(language)", short, as a diner would say it.
        - `description`: ONE plain sentence in "\(language)" saying what the dish is. No marketing words.
        - `originalName`/`originalDescription`: as printed in the menu's language \
        (null if the menu is already in "\(language)").
        - `menuNumber`: the menu's own number for the dish exactly as printed ("07", "A3"), else null.
        - `section`: the menu's own section heading for this dish, translated into "\(language)" \
        ("Salads and soups", "First courses"), else null.
        - `kind`: the generic kind of dish in English, singular, one or two words ("pizza", "pasta", \
        "curry", "salad", "sandwich", "soup", "cake"), so a photo search can check it found the right \
        thing. Null for drinks or when unclear.
        - `course`: one of \(Course.allCases.map(\.rawValue).joined(separator: ", ")).
        - `dietaryTags`: ONLY from \(DietaryTag.allCases.map(\.rawValue).joined(separator: ", ")).
        - `allergens`: allergens the dish CONTAINS based on its listed or defining ingredients, ONLY from \
        \(Allergen.allCases.map(\.rawValue).joined(separator: ", ")).
        - `allergenSources`: for each allergen, the ingredient that brings it, lowercase English \
        ({"allergen": "shellfish", "ingredient": "dried shrimp"}).
        - `likelyIngredients`: ingredients the menu does NOT list but this dish usually contains \
        and that matter for allergies or diets: shrimp paste, fish sauce, oyster sauce, animal rennet \
        in cheese, lard, anchovy, egg in fresh pasta, peanuts in a sauce. Each has `name` (lowercase \
        English), `allergens` it brings, `breaks` (dietary tags it breaks, e.g. vegetarian), `question` \
        (a short polite question to the waiter in the MENU's language), `questionTranslation` (that \
        question in "\(language)"), and `note` (a few words for a tile, e.g. "Parmigiano uses animal \
        rennet", or null). Empty when nothing is likely hidden. Do not repeat listed ingredients here.
        - `protein`: the meat or fish in a few words in "\(language)" ("Beef and pork", "Prawns"), \
        or null when there is none.
        - `spiceLevel`: one of \(SpiceLevel.allCases.map(\.rawValue).joined(separator: ", ")).
        - `ingredients`: notable ingredients (lowercase, in "\(language)").
        - `ingredientKeys`: the same ingredients, plus the protein, under one standard lowercase singular \
        ENGLISH name each, whatever the menu's language ("funghi" → "mushroom", "peperoni" → \
        "bell pepper", "fior di latte" → "mozzarella", "gamberi" → "prawn", "salame piccante" → \
        "salami"), with its `family`, one of \(IngredientFamily.allCases.map(\.rawValue).joined(separator: ", ")). \
        Use the same name for the same ingredient across all dishes, so diners can filter by it.
        - `isPopular`: true only if the menu marks it as a house special / popular / chef's choice.
        - `price`/`currency`: when present (ISO 4217 code).
        - `plate`: the closest drawn plate for the dish, one of \
        \(PlateArchetype.allCases.map(\.rawValue).joined(separator: ", ")).
        - `confidence`: 0 to 1.
        """
    }

    /// JSON-Schema describing the structured output we want back.
    static let schema: JSONValue = {
        let allergenEnum = JSONValue.stringEnum(Allergen.allCases.map(\.rawValue))
        let tagEnum = JSONValue.stringEnum(DietaryTag.allCases.map(\.rawValue))
        let allergenSource = JSONValue.schemaObject(
            properties: ["allergen": allergenEnum, "ingredient": .stringType],
            required: ["allergen", "ingredient"]
        )
        let likely = JSONValue.schemaObject(
            properties: [
                "name": .stringType,
                "allergens": .arrayOf(allergenEnum),
                "breaks": .arrayOf(tagEnum),
                "question": .nullableString,
                "questionTranslation": .nullableString,
                "note": .nullableString,
            ],
            required: ["name", "allergens", "breaks", "question", "questionTranslation", "note"]
        )
        let ingredientKey = JSONValue.schemaObject(
            properties: ["name": .stringType, "family": .stringEnum(IngredientFamily.allCases.map(\.rawValue))],
            required: ["name", "family"]
        )
        let dish = JSONValue.schemaObject(
            properties: [
                "name": .stringType,
                "originalName": .nullableString,
                "description": .nullableString,
                "originalDescription": .nullableString,
                "menuNumber": .nullableString,
                "section": .nullableString,
                "price": .object(["type": .array([.string("number"), .string("null")])]),
                "currency": .nullableString,
                "kind": .nullableString,
                "course": .stringEnum(Course.allCases.map(\.rawValue)),
                "dietaryTags": .arrayOf(tagEnum),
                "allergens": .arrayOf(allergenEnum),
                "allergenSources": .arrayOf(allergenSource),
                "likelyIngredients": .arrayOf(likely),
                "protein": .nullableString,
                "spiceLevel": .stringEnum(SpiceLevel.allCases.map(\.rawValue)),
                "ingredients": .arrayOf(.stringType),
                "ingredientKeys": .arrayOf(ingredientKey),
                "isPopular": .object(["type": .string("boolean")]),
                "plate": .stringEnum(PlateArchetype.allCases.map(\.rawValue)),
                "confidence": .object(["type": .string("number")]),
            ],
            required: ["name", "originalName", "description", "originalDescription", "menuNumber",
                       "section", "price", "currency", "kind", "course", "dietaryTags", "allergens",
                       "allergenSources", "likelyIngredients", "protein", "spiceLevel",
                       "ingredients", "ingredientKeys", "isPopular", "plate", "confidence"]
        )
        return .schemaObject(
            properties: [
                "restaurantName": .nullableString,
                "originalRestaurantName": .nullableString,
                "cuisine": .nullableString,
                "sourceLanguage": .nullableString,
                "currency": .nullableString,
                "dishes": .arrayOf(dish),
            ],
            required: ["restaurantName", "originalRestaurantName", "cuisine", "sourceLanguage",
                       "currency", "dishes"]
        )
    }()
}

// MARK: - LLM output → domain

struct LLMMenu: Codable {
    var restaurantName: String?
    var originalRestaurantName: String?
    var cuisine: String?
    var sourceLanguage: String?
    var currency: String?
    var dishes: [LLMDish]

    func toParsedMenu(defaultCurrency: String?) -> ParsedMenu {
        let menuCurrency = currency ?? defaultCurrency
        return ParsedMenu(
            restaurantName: restaurantName,
            originalRestaurantName: originalRestaurantName,
            cuisine: cuisine,
            sourceLanguage: sourceLanguage,
            currency: menuCurrency,
            dishes: dishes.map { $0.toDish(defaultCurrency: menuCurrency) }
        )
    }
}

struct LLMDish: Codable {
    struct Source: Codable {
        var allergen: String
        var ingredient: String
    }

    struct Key: Codable {
        var name: String
        var family: String?
    }

    struct Likely: Codable {
        var name: String
        var allergens: [String]?
        var breaks: [String]?
        var question: String?
        var questionTranslation: String?
        var note: String?
    }

    var name: String
    var originalName: String?
    var description: String?
    var originalDescription: String?
    var menuNumber: String?
    var section: String?
    var price: Double?
    var currency: String?
    var kind: String?
    var course: String?
    var dietaryTags: [String]?
    var allergens: [String]?
    var allergenSources: [Source]?
    var likelyIngredients: [Likely]?
    var protein: String?
    var spiceLevel: String?
    var ingredients: [String]?
    var ingredientKeys: [Key]?
    var isPopular: Bool?
    var plate: String?
    var confidence: Double?

    func toDish(defaultCurrency: String?) -> Dish {
        Dish(
            name: name,
            originalName: originalName.nonEmpty,
            description: description.nonEmpty,
            originalDescription: originalDescription.nonEmpty,
            menuNumber: menuNumber.nonEmpty,
            price: price.map { Decimal(string: String($0)) ?? Decimal($0) },
            currency: currency ?? defaultCurrency,
            course: course.flatMap(Course.init(rawValue:)) ?? .other,
            section: section.nonEmpty,
            kind: kind.nonEmpty?.lowercased(),
            dietaryTags: (dietaryTags ?? []).compactMap(DietaryTag.init(rawValue:)),
            allergens: (allergens ?? []).compactMap(Allergen.init(rawValue:)),
            allergenSources: (allergenSources ?? []).compactMap { source in
                Allergen(rawValue: source.allergen).map {
                    AllergenSource(allergen: $0, ingredient: source.ingredient.lowercased())
                }
            },
            likelyIngredients: (likelyIngredients ?? []).map { likely in
                LikelyIngredient(
                    name: likely.name.lowercased(),
                    allergens: (likely.allergens ?? []).compactMap(Allergen.init(rawValue:)),
                    breaks: (likely.breaks ?? []).compactMap(DietaryTag.init(rawValue:)),
                    question: likely.question.nonEmpty,
                    questionTranslation: likely.questionTranslation.nonEmpty,
                    note: likely.note.nonEmpty
                )
            },
            protein: protein.nonEmpty,
            spiceLevel: spiceLevel.flatMap(SpiceLevel.init(rawValue:)) ?? .none,
            ingredients: ingredients ?? [],
            ingredientKeys: (ingredientKeys ?? []).compactMap { key in
                Optional(key.name).nonEmpty.map {
                    IngredientKey(name: $0.lowercased(),
                                  family: key.family.flatMap(IngredientFamily.init(rawValue:)) ?? .other)
                }
            },
            isPopular: isPopular ?? false,
            plate: plate.flatMap(PlateArchetype.init(rawValue:)) ?? .generic,
            confidence: confidence ?? 0.7
        )
    }
}

extension Optional where Wrapped == String {
    /// `nil` for a missing or blank string, otherwise the trimmed string.
    var nonEmpty: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
