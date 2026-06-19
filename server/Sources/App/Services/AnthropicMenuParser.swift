import Vapor
import MiseShared

/// Parses + enriches menu text with the Anthropic Messages API.
///
/// There is no official Anthropic Swift SDK, so this calls the REST API directly
/// (the documented approach for unsupported languages) and uses structured
/// outputs so the model returns JSON matching our schema.
struct AnthropicMenuParser {
    let apiKey: String
    let model: String

    private static let endpoint = URI(string: "https://api.anthropic.com/v1/messages")
    private static let apiVersion = "2023-06-01"

    func parse(
        text: String,
        hints: MenuParseHints?,
        client: any Client,
        logger: Logger
    ) async throws -> ParsedMenu {
        let requestBody = AnthropicRequest(
            model: model,
            max_tokens: 8000,
            system: Self.systemPrompt(hints: hints),
            messages: [.init(role: "user", content: text)],
            output_config: .init(format: .init(type: "json_schema", schema: Self.schema))
        )

        let response = try await client.post(Self.endpoint) { req in
            req.headers.replaceOrAdd(name: "x-api-key", value: apiKey)
            req.headers.replaceOrAdd(name: "anthropic-version", value: Self.apiVersion)
            req.headers.contentType = .json
            try req.content.encode(requestBody)
        }

        guard response.status == .ok else {
            let bodyText = response.body.map { String(buffer: $0) } ?? ""
            throw Abort(.badGateway, reason: "Anthropic returned \(response.status): \(bodyText)")
        }

        let decoded = try response.content.decode(AnthropicResponse.self)
        guard let json = decoded.content.first(where: { $0.type == "text" })?.text,
              let data = json.data(using: .utf8) else {
            throw Abort(.badGateway, reason: "Anthropic response contained no text block.")
        }

        let llmMenu = try JSONDecoder().decode(LLMMenu.self, from: data)
        return llmMenu.toParsedMenu(defaultCurrency: hints?.assumedCurrency)
    }

    private static func systemPrompt(hints: MenuParseHints?) -> String {
        let language = hints?.preferredLanguage ?? "en"
        return """
        You convert raw OCR text from a restaurant menu into structured data.
        Extract every dish — do not invent dishes that are not in the text.

        For each dish:
        - `name`/`description`: translated into language code "\(language)".
        - `originalName`/`originalDescription`: kept in the menu's original language \
        (null if the menu is already in "\(language)").
        - `course`: one of \(Course.allCases.map(\.rawValue).joined(separator: ", ")).
        - `dietaryTags`: ONLY from \(DietaryTag.allCases.map(\.rawValue).joined(separator: ", ")).
        - `allergens`: allergens the dish CONTAINS, ONLY from \
        \(Allergen.allCases.map(\.rawValue).joined(separator: ", ")).
        - `spiceLevel`: one of \(SpiceLevel.allCases.map(\.rawValue).joined(separator: ", ")).
        - `ingredients`: notable ingredients (lowercase).
        - `isPopular`: true only if the menu marks it as a house special / popular / chef's choice.
        - `price`/`currency`: when present (ISO 4217 code).
        - `confidence`: 0 to 1.
        """
    }

    /// JSON-Schema describing the structured output we want back.
    private static let schema: JSONValue = {
        let dish = JSONValue.schemaObject(
            properties: [
                "name": .object(["type": .string("string")]),
                "originalName": .object(["type": .array([.string("string"), .string("null")])]),
                "description": .object(["type": .array([.string("string"), .string("null")])]),
                "originalDescription": .object(["type": .array([.string("string"), .string("null")])]),
                "price": .object(["type": .array([.string("number"), .string("null")])]),
                "currency": .object(["type": .array([.string("string"), .string("null")])]),
                "course": .object(["type": .string("string"),
                                   "enum": .array(Course.allCases.map { .string($0.rawValue) })]),
                "dietaryTags": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string"),
                                      "enum": .array(DietaryTag.allCases.map { .string($0.rawValue) })]),
                ]),
                "allergens": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string"),
                                      "enum": .array(Allergen.allCases.map { .string($0.rawValue) })]),
                ]),
                "spiceLevel": .object(["type": .string("string"),
                                       "enum": .array(SpiceLevel.allCases.map { .string($0.rawValue) })]),
                "ingredients": .object(["type": .string("array"),
                                        "items": .object(["type": .string("string")])]),
                "isPopular": .object(["type": .string("boolean")]),
                "confidence": .object(["type": .string("number")]),
            ],
            required: ["name", "originalName", "description", "originalDescription", "price",
                       "currency", "course", "dietaryTags", "allergens", "spiceLevel",
                       "ingredients", "isPopular", "confidence"]
        )
        return .schemaObject(
            properties: [
                "restaurantName": .object(["type": .array([.string("string"), .string("null")])]),
                "sourceLanguage": .object(["type": .array([.string("string"), .string("null")])]),
                "currency": .object(["type": .array([.string("string"), .string("null")])]),
                "dishes": .object(["type": .string("array"), "items": dish]),
            ],
            required: ["restaurantName", "sourceLanguage", "currency", "dishes"]
        )
    }()
}

// MARK: - Wire types

private struct AnthropicRequest: Content {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [Message]
    let output_config: OutputConfig

    struct Message: Content {
        let role: String
        let content: String
    }

    struct OutputConfig: Content {
        let format: Format
    }

    struct Format: Content {
        let type: String
        let schema: JSONValue
    }
}

private struct AnthropicResponse: Content {
    let content: [Block]

    struct Block: Content {
        let type: String
        let text: String?
    }
}

// MARK: - LLM output → domain

private struct LLMMenu: Codable {
    var restaurantName: String?
    var sourceLanguage: String?
    var currency: String?
    var dishes: [LLMDish]

    func toParsedMenu(defaultCurrency: String?) -> ParsedMenu {
        ParsedMenu(
            restaurantName: restaurantName,
            sourceLanguage: sourceLanguage,
            currency: currency ?? defaultCurrency,
            dishes: dishes.map { $0.toDish(defaultCurrency: currency ?? defaultCurrency) }
        )
    }
}

private struct LLMDish: Codable {
    var name: String
    var originalName: String?
    var description: String?
    var originalDescription: String?
    var price: Double?
    var currency: String?
    var course: String?
    var dietaryTags: [String]?
    var allergens: [String]?
    var spiceLevel: String?
    var ingredients: [String]?
    var isPopular: Bool?
    var confidence: Double?

    func toDish(defaultCurrency: String?) -> Dish {
        Dish(
            name: name,
            originalName: originalName,
            description: description,
            originalDescription: originalDescription,
            price: price.map { Decimal($0) },
            currency: currency ?? defaultCurrency,
            course: course.flatMap(Course.init(rawValue:)) ?? .other,
            dietaryTags: (dietaryTags ?? []).compactMap(DietaryTag.init(rawValue:)),
            allergens: (allergens ?? []).compactMap(Allergen.init(rawValue:)),
            spiceLevel: spiceLevel.flatMap(SpiceLevel.init(rawValue:)) ?? .none,
            ingredients: ingredients ?? [],
            isPopular: isPopular ?? false,
            confidence: confidence ?? 0.7
        )
    }
}
