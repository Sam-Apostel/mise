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
    /// The generic kind of dish in English ("pizza"). A photo must show one.
    public var kind: String?
    /// The menu's section heading ("Pizzas"); stands in for `kind` when that is missing.
    public var section: String?

    public init(id: UUID, name: String, originalName: String? = nil, cuisine: String? = nil,
                kind: String? = nil, section: String? = nil) {
        self.id = id
        self.name = name
        self.originalName = originalName
        self.cuisine = cuisine
        self.kind = kind
        self.section = section
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
    /// No photo because a source was rate-limited or slow, not because none
    /// exists: worth asking again later.
    public var retry: Bool

    public init(id: UUID, image: DishImage?, retry: Bool = false) {
        self.id = id
        self.image = image
        self.retry = retry
    }

    private enum CodingKeys: String, CodingKey { case id, image, retry }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        image = try c.decodeIfPresent(DishImage.self, forKey: .image)
        retry = try c.decodeIfPresent(Bool.self, forKey: .retry) ?? false
    }
}

public struct DishImagesResponse: Codable, Hashable, Sendable {
    public var results: [DishImageResult]
    public init(results: [DishImageResult]) { self.results = results }
}

// MARK: - Filters from a sentence

/// `POST /v1/filters/interpret`: "only pizzas with mozzarella, no mushrooms"
/// turned into filters, against what this menu actually has.
public struct InterpretFiltersRequest: Codable, Hashable, Sendable {
    public var text: String
    /// The menu's section headings, exactly as shown.
    public var sections: [String]
    /// The standard ingredient names on this menu ("mozzarella", "bell pepper").
    public var ingredients: [String]

    public init(text: String, sections: [String], ingredients: [String]) {
        self.text = text
        self.sections = sections
        self.ingredients = ingredients
    }
}

/// What a sentence asks for. Every field is optional; an empty intent means
/// the sentence was not a filter (the app then treats it as a search).
public struct FilterIntent: Codable, Hashable, Sendable {
    /// Show only these sections (titles from the request).
    public var onlySections: [String]
    /// Hide these sections.
    public var hideSections: [String]
    /// Standard ingredient names or families the diner wants.
    public var want: [String]
    /// Standard ingredient names or families to avoid ("mushroom", "seafood").
    public var avoid: [String]
    public var requiredTags: [DietaryTag]
    public var maxSpice: SpiceLevel?
    public var maxPrice: Decimal?

    public init(onlySections: [String] = [], hideSections: [String] = [], want: [String] = [],
                avoid: [String] = [], requiredTags: [DietaryTag] = [], maxSpice: SpiceLevel? = nil,
                maxPrice: Decimal? = nil) {
        self.onlySections = onlySections
        self.hideSections = hideSections
        self.want = want
        self.avoid = avoid
        self.requiredTags = requiredTags
        self.maxSpice = maxSpice
        self.maxPrice = maxPrice
    }

    public var isEmpty: Bool {
        onlySections.isEmpty && hideSections.isEmpty && want.isEmpty && avoid.isEmpty
            && requiredTags.isEmpty && maxSpice == nil && maxPrice == nil
    }
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
