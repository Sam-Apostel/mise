import Foundation

/// A single dish parsed from a scanned menu.
///
/// `MiseShared` is compiled for both the iOS app and the Linux Vapor server, so
/// everything here stays Foundation-only and `Sendable`.
public struct Dish: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// The dish name as it should be displayed (translated into the user's language when needed).
    public var name: String
    /// The dish name in the menu's original language. Shown alongside `name` on the
    /// detail screen ("in their language + yours").
    public var originalName: String?
    /// The raw line(s) the dish was extracted from, kept for debugging/traceability.
    public var originalText: String?
    /// A short description in the user's language.
    public var description: String?
    /// The description in the menu's original language, for the bilingual detail view.
    public var originalDescription: String?
    public var price: Decimal?
    /// ISO 4217 currency code (e.g. "EUR", "USD") when known.
    public var currency: String?
    public var course: Course
    public var dietaryTags: [DietaryTag]
    /// Allergens the dish *contains*.
    public var allergens: [Allergen]
    public var spiceLevel: SpiceLevel
    /// Notable ingredients, used both for display and for richer filtering.
    public var ingredients: [String]
    /// Whether the dish is a popular / frequently ordered item ("popular · ordered a lot").
    public var isPopular: Bool
    /// URL of a representative image for the dish, populated by the enrichment step.
    public var imageURL: URL?
    /// Parser confidence in the range 0...1.
    public var confidence: Double

    public init(
        id: UUID = UUID(),
        name: String,
        originalName: String? = nil,
        originalText: String? = nil,
        description: String? = nil,
        originalDescription: String? = nil,
        price: Decimal? = nil,
        currency: String? = nil,
        course: Course = .other,
        dietaryTags: [DietaryTag] = [],
        allergens: [Allergen] = [],
        spiceLevel: SpiceLevel = .none,
        ingredients: [String] = [],
        isPopular: Bool = false,
        imageURL: URL? = nil,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.originalName = originalName
        self.originalText = originalText
        self.description = description
        self.originalDescription = originalDescription
        self.price = price
        self.currency = currency
        self.course = course
        self.dietaryTags = dietaryTags
        self.allergens = allergens
        self.spiceLevel = spiceLevel
        self.ingredients = ingredients
        self.isPopular = isPopular
        self.imageURL = imageURL
        self.confidence = confidence
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
