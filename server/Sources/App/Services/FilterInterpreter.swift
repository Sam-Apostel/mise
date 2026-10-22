import Vapor
import MiseShared

/// Turns what a diner says ("only pizzas with mozzarella, no mushrooms or
/// seafood") into filters for the menu they are reading.
///
/// The model chooses from this menu's own section titles and ingredient names.
/// Without a key, or when the call fails, the offline `FilterIntentParser` answers.
struct FilterInterpreter: Sendable {
    let apiKey: String?
    let model: String

    func interpret(_ request: InterpretFiltersRequest, client: any Client, logger: Logger) async -> FilterIntent {
        let offline = FilterIntentParser.parse(request.text, sections: request.sections, ingredients: request.ingredients)
        guard let apiKey else { return offline }
        do {
            let data = try await AnthropicStructuredCall(apiKey: apiKey, model: model).run(
                system: Self.systemPrompt,
                user: Self.userPrompt(for: request),
                schema: Self.schema(sections: request.sections),
                maxTokens: 800,
                client: client,
                timeout: .seconds(20)
            )
            return try Self.decode(data, sections: request.sections)
        } catch {
            logger.error("Anthropic filter interpretation failed, using the offline parser: \(error)")
            return offline
        }
    }

    /// Maps the model's JSON onto a `FilterIntent`, keeping only sections the menu has.
    static func decode(_ data: Data, sections: [String]) throws -> FilterIntent {
        let llm = try JSONDecoder().decode(LLMIntent.self, from: data)
        func clean(_ items: [String]) -> [String] {
            var seen = Set<String>()
            return items.compactMap { Optional($0.lowercased()).nonEmpty }.filter { seen.insert($0).inserted }
        }
        return FilterIntent(
            onlySections: llm.onlySections.filter(sections.contains),
            hideSections: llm.hideSections.filter(sections.contains),
            want: clean(llm.want),
            avoid: clean(llm.avoid),
            requiredTags: llm.requiredTags.compactMap(DietaryTag.init(rawValue:)),
            maxSpice: llm.maxSpice.flatMap(SpiceLevel.init(rawValue:)),
            maxPrice: llm.maxPrice.map { Decimal(string: String($0)) ?? Decimal($0) }
        )
    }

    static let systemPrompt = """
    You turn what a diner says at a restaurant into filters for the menu they are reading. Return:
    - `onlySections`: section titles the diner wants to see, exactly as listed ("only pizzas", \
    "I want a pizza" → the pizza sections). Empty when they don't narrow by section.
    - `hideSections`: section titles they don't want ("no desserts").
    - `want`: ingredients they want in the dish. Use the menu's ingredient names from the list \
    when one fits ("peppers", "peperoni" → "bell pepper").
    - `avoid`: ingredients that must not be in the dish. For a whole group use the family name: \
    meat, seafood, cheese, mushroom, egg, nuts ("no fish", "no seafood" → "seafood"; "no mushrooms" → "mushroom").
    - `requiredTags`: diets they ask for ("vegetarian", "gluten free").
    - `maxSpice`: the hottest they want, or null.
    - `maxPrice`: the most they want to pay as a number in the menu's currency, or null.
    Names are lowercase singular English. When the sentence is only a dish name or a question, \
    return everything empty.
    """

    static func userPrompt(for request: InterpretFiltersRequest) -> String {
        """
        Sections: \(request.sections.joined(separator: " | "))
        Ingredients on this menu: \(request.ingredients.joined(separator: ", "))
        The diner said: \(request.text)
        """
    }

    static func schema(sections: [String]) -> JSONValue {
        let section: JSONValue = sections.isEmpty ? .stringType : .stringEnum(sections)
        return .schemaObject(
            properties: [
                "onlySections": .arrayOf(section),
                "hideSections": .arrayOf(section),
                "want": .arrayOf(.stringType),
                "avoid": .arrayOf(.stringType),
                "requiredTags": .arrayOf(.stringEnum(DietaryTag.allCases.map(\.rawValue))),
                "maxSpice": .object(["type": .array([.string("string"), .string("null")]),
                                     "enum": .array(SpiceLevel.allCases.map { .string($0.rawValue) } + [.null])]),
                "maxPrice": .object(["type": .array([.string("number"), .string("null")])]),
            ],
            required: ["onlySections", "hideSections", "want", "avoid", "requiredTags", "maxSpice", "maxPrice"]
        )
    }
}

private struct LLMIntent: Codable {
    var onlySections: [String]
    var hideSections: [String]
    var want: [String]
    var avoid: [String]
    var requiredTags: [String]
    var maxSpice: String?
    var maxPrice: Double?
}

extension Application {
    private struct FilterInterpreterKey: StorageKey {
        typealias Value = FilterInterpreter
    }

    var filterInterpreter: FilterInterpreter {
        get { storage[FilterInterpreterKey.self] ?? FilterInterpreter(apiKey: nil, model: "") }
        set { storage[FilterInterpreterKey.self] = newValue }
    }
}
