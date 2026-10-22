import Foundation

/// A single dish parsed from a scanned menu.
///
/// `MiseShared` is compiled for both the iOS app and the Linux Vapor server, so
/// everything here stays Foundation-only and `Sendable`.
///
/// Every field added after the first release decodes with a default when it is
/// missing, so an older server (or a cached menu) still reads.
public struct Dish: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// The dish name as it should be displayed (translated into the user's language when needed).
    public var name: String
    /// The dish name in the menu's original language and script ("ต้มข่าไก่").
    public var originalName: String?
    /// The raw line(s) the dish was extracted from, kept for debugging/traceability.
    public var originalText: String?
    /// One plain sentence in the user's language: what the dish is.
    public var description: String?
    /// The description in the menu's original language, for the bilingual detail view.
    public var originalDescription: String?
    /// The menu's own number for the dish ("07"), so the diner can order by pointing.
    public var menuNumber: String?
    public var price: Decimal?
    /// ISO 4217 currency code (e.g. "EUR", "THB") when known.
    public var currency: String?
    public var course: Course
    /// The menu's own section heading, translated ("Salads and soups", "Primi").
    /// Dishes are grouped by this when present, in menu order.
    public var section: String?
    /// The generic kind of dish in English, singular ("pizza", "pasta", "curry").
    /// Narrows the photo search so "Allegra" finds a pizza, not a train.
    public var kind: String?
    public var dietaryTags: [DietaryTag]
    /// Allergens the dish *contains*.
    public var allergens: [Allergen]
    /// Which listed ingredient brings each allergen ("dried shrimp" → shellfish),
    /// so a verdict can say *why* instead of naming the allergen class.
    public var allergenSources: [AllergenSource]
    /// Ingredients the menu does not list but the dish usually has (shrimp paste,
    /// fish sauce, oyster sauce, animal rennet). They drive the "ask" verdict.
    public var likelyIngredients: [LikelyIngredient]
    /// The meat or fish in the dish, in a few words ("Beef and pork", "Meat ragù").
    /// The reason shown when a dish fails a vegetarian or vegan filter.
    public var protein: String?
    public var spiceLevel: SpiceLevel
    /// Notable ingredients, used both for display and for richer filtering.
    public var ingredients: [String]
    /// `ingredients` under standard English names with their family
    /// ("funghi" → mushroom, mushroom). Empty for menus parsed before this
    /// existed; `keys` then looks them up offline.
    public var ingredientKeys: [IngredientKey]
    /// Whether the dish is a popular / frequently ordered item.
    public var isPopular: Bool
    /// A typical photo of the dish (not this kitchen's), from the free image chain.
    public var imageURL: URL?
    /// Attribution line for `imageURL` ("Photo: Takeaway, CC BY-SA 3.0").
    public var imageCredit: String?
    /// The drawn plate shown when no photo is found (and while photos load).
    public var plate: PlateArchetype
    /// Parser confidence in the range 0...1.
    public var confidence: Double

    public init(
        id: UUID = UUID(),
        name: String,
        originalName: String? = nil,
        originalText: String? = nil,
        description: String? = nil,
        originalDescription: String? = nil,
        menuNumber: String? = nil,
        price: Decimal? = nil,
        currency: String? = nil,
        course: Course = .other,
        section: String? = nil,
        kind: String? = nil,
        dietaryTags: [DietaryTag] = [],
        allergens: [Allergen] = [],
        allergenSources: [AllergenSource] = [],
        likelyIngredients: [LikelyIngredient] = [],
        protein: String? = nil,
        spiceLevel: SpiceLevel = .none,
        ingredients: [String] = [],
        ingredientKeys: [IngredientKey] = [],
        isPopular: Bool = false,
        imageURL: URL? = nil,
        imageCredit: String? = nil,
        plate: PlateArchetype = .generic,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.originalName = originalName
        self.originalText = originalText
        self.description = description
        self.originalDescription = originalDescription
        self.menuNumber = menuNumber
        self.price = price
        self.currency = currency
        self.course = course
        self.section = section
        self.kind = kind
        self.dietaryTags = dietaryTags
        self.allergens = allergens
        self.allergenSources = allergenSources
        self.likelyIngredients = likelyIngredients
        self.protein = protein
        self.spiceLevel = spiceLevel
        self.ingredients = ingredients
        self.ingredientKeys = ingredientKeys
        self.isPopular = isPopular
        self.imageURL = imageURL
        self.imageCredit = imageCredit
        self.plate = plate
        self.confidence = confidence
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, originalName, originalText, description, originalDescription, menuNumber
        case price, currency, course, section, kind, dietaryTags, allergens, allergenSources
        case likelyIngredients, protein, spiceLevel, ingredients, ingredientKeys, isPopular, imageURL
        case imageCredit, plate, confidence
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        originalName = try c.decodeIfPresent(String.self, forKey: .originalName)
        originalText = try c.decodeIfPresent(String.self, forKey: .originalText)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        originalDescription = try c.decodeIfPresent(String.self, forKey: .originalDescription)
        menuNumber = try c.decodeIfPresent(String.self, forKey: .menuNumber)
        price = try c.decodeIfPresent(Decimal.self, forKey: .price)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        course = (try? c.decodeIfPresent(Course.self, forKey: .course)) ?? .other
        section = try c.decodeIfPresent(String.self, forKey: .section)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        dietaryTags = try c.decodeIfPresent([DietaryTag].self, forKey: .dietaryTags) ?? []
        allergens = try c.decodeIfPresent([Allergen].self, forKey: .allergens) ?? []
        allergenSources = try c.decodeIfPresent([AllergenSource].self, forKey: .allergenSources) ?? []
        likelyIngredients = try c.decodeIfPresent([LikelyIngredient].self, forKey: .likelyIngredients) ?? []
        protein = try c.decodeIfPresent(String.self, forKey: .protein)
        spiceLevel = (try? c.decodeIfPresent(SpiceLevel.self, forKey: .spiceLevel)) ?? .none
        ingredients = try c.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        ingredientKeys = try c.decodeIfPresent([IngredientKey].self, forKey: .ingredientKeys) ?? []
        isPopular = try c.decodeIfPresent(Bool.self, forKey: .isPopular) ?? false
        imageURL = try c.decodeIfPresent(URL.self, forKey: .imageURL)
        imageCredit = try c.decodeIfPresent(String.self, forKey: .imageCredit)
        plate = (try? c.decodeIfPresent(PlateArchetype.self, forKey: .plate)) ?? .generic
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 1.0
    }

    /// The heading this dish is grouped under on the menu screen.
    public var sectionTitle: String { section ?? course.displayName }
}

/// One listed ingredient and the allergen it brings.
public struct AllergenSource: Codable, Hashable, Sendable {
    public var allergen: Allergen
    /// The ingredient as listed, lowercase ("dried shrimp").
    public var ingredient: String

    public init(allergen: Allergen, ingredient: String) {
        self.allergen = allergen
        self.ingredient = ingredient
    }
}

/// An ingredient the menu does not mention but the dish usually contains.
///
/// A dish that only *probably* contains something a person avoids gets the
/// "ask" verdict, with the question in the menu's language.
public struct LikelyIngredient: Codable, Hashable, Sendable {
    /// Lowercase English name ("shrimp paste").
    public var name: String
    /// Allergens this ingredient would bring.
    public var allergens: [Allergen]
    /// Dietary tags it would break (animal rennet breaks vegetarian).
    public var breaks: [DietaryTag]
    /// The question to ask, in the menu's language ("มีกะปิไหม").
    public var question: String?
    /// The same question in the user's language ("Does it have shrimp paste?").
    public var questionTranslation: String?
    /// A short custom line for the tile ("Parmigiano uses animal rennet").
    public var note: String?

    public init(
        name: String,
        allergens: [Allergen] = [],
        breaks: [DietaryTag] = [],
        question: String? = nil,
        questionTranslation: String? = nil,
        note: String? = nil
    ) {
        self.name = name
        self.allergens = allergens
        self.breaks = breaks
        self.question = question
        self.questionTranslation = questionTranslation
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case name, allergens, breaks, question, questionTranslation, note
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        allergens = try c.decodeIfPresent([Allergen].self, forKey: .allergens) ?? []
        breaks = try c.decodeIfPresent([DietaryTag].self, forKey: .breaks) ?? []
        question = try c.decodeIfPresent(String.self, forKey: .question)
        questionTranslation = try c.decodeIfPresent(String.self, forKey: .questionTranslation)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

/// Coarse grouping used to organise a menu into sections.
public enum Course: String, Codable, CaseIterable, Sendable {
    case starter
    case main
    case side
    case dessert
    case drink
    case other

    public var displayName: String {
        switch self {
        case .starter: return "Starters"
        case .main: return "Mains"
        case .side: return "Sides"
        case .dessert: return "Desserts"
        case .drink: return "Drinks"
        case .other: return "Other"
        }
    }
}
