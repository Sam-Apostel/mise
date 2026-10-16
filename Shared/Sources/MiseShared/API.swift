import Foundation

/// Request/response contracts shared by the app and the server.
public enum MiseAPI {
    /// Current API version prefix, e.g. `/v1/menu/parse`.
    public static let versionPrefix = "v1"
}

/// Optional hints the client can pass to improve parsing.
public struct MenuParseHints: Codable, Hashable, Sendable {
    /// Caller's preferred language for descriptions (BCP-47), e.g. "en".
    public var preferredLanguage: String?
    /// Currency to assume when the menu omits symbols.
    public var assumedCurrency: String?

    public init(preferredLanguage: String? = nil, assumedCurrency: String? = nil) {
        self.preferredLanguage = preferredLanguage
        self.assumedCurrency = assumedCurrency
    }
}

/// `POST /v1/menu/parse` request body.
///
/// OCR happens on-device; the client sends recognised text rather than the image.
public struct ParseMenuRequest: Codable, Hashable, Sendable {
    public var text: String
    public var hints: MenuParseHints?

    public init(text: String, hints: MenuParseHints? = nil) {
        self.text = text
        self.hints = hints
    }
}

/// `POST /v1/menu/parse` response body.
public struct ParseMenuResponse: Codable, Hashable, Sendable {
    public var menu: ParsedMenu
    /// Identifier of the parsing strategy that produced the menu ("anthropic" | "heuristic").
    public var parser: String

    public init(menu: ParsedMenu, parser: String) {
        self.menu = menu
        self.parser = parser
    }
}

// MARK: - Dish images

/// One dish to find a photo for. `POST /v1/images` takes a batch of these.
public struct DishImageQuery: Codable, Hashable, Sendable {
    /// The client's dish id, echoed back so results can be matched up.
    public var id: UUID
    /// English name ("Green curry, chicken").
    public var name: String
    /// Name in the menu's language ("แกงเขียวหวานไก่"), searched first.
    public var originalName: String?
    /// Cuisine ("Thai"); part of the cache key and the stock-photo query.
    public var cuisine: String?

    public init(id: UUID, name: String, originalName: String? = nil, cuisine: String? = nil) {
        self.id = id
        self.name = name
        self.originalName = originalName
        self.cuisine = cuisine
    }
}

public struct DishImagesRequest: Codable, Hashable, Sendable {
    public var dishes: [DishImageQuery]
    public init(dishes: [DishImageQuery]) { self.dishes = dishes }
}

/// A typical photo of a dish from the free chain.
public struct DishImage: Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable {
        case commons, pexels, pixabay
    }

    public var url: URL
    /// The credit line to show under the photo on the dish screen.
    public var credit: String?
    public var source: Source

    public init(url: URL, credit: String?, source: Source) {
        self.url = url
        self.credit = credit
        self.source = source
    }
}

public struct DishImageResult: Codable, Hashable, Sendable {
    public var id: UUID
    /// `nil` when every tier missed: the app draws the plate.
    public var image: DishImage?
    public init(id: UUID, image: DishImage?) {
        self.id = id
        self.image = image
    }
}

public struct DishImagesResponse: Codable, Hashable, Sendable {
    public var results: [DishImageResult]
    public init(results: [DishImageResult]) { self.results = results }
}

// MARK: - Phrases

/// `POST /v1/phrases`: the waiter-card words for one person, in the menu's language.
public struct PhrasesRequest: Codable, Hashable, Sendable {
    public var language: String
    public var allergens: [Allergen]
    public var speech: Profile.Speech

    public init(language: String, allergens: [Allergen], speech: Profile.Speech = .neutral) {
        self.language = language
        self.allergens = allergens
        self.speech = speech
    }
}

/// Standard error envelope returned by the API.
public struct APIErrorResponse: Codable, Hashable, Sendable {
    public var error: String
    public var reason: String?

    public init(error: String, reason: String? = nil) {
        self.error = error
        self.reason = reason
    }
}
