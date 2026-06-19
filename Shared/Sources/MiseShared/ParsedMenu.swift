import Foundation

/// A full menu after OCR + parsing/enrichment.
public struct ParsedMenu: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var restaurantName: String?
    /// BCP-47 language code of the source menu, when detected (e.g. "fr", "en").
    public var sourceLanguage: String?
    /// Default ISO 4217 currency for the menu, when detected.
    public var currency: String?
    public var dishes: [Dish]

    public init(
        id: UUID = UUID(),
        restaurantName: String? = nil,
        sourceLanguage: String? = nil,
        currency: String? = nil,
        dishes: [Dish] = []
    ) {
        self.id = id
        self.restaurantName = restaurantName
        self.sourceLanguage = sourceLanguage
        self.currency = currency
        self.dishes = dishes
    }

    /// Dishes grouped by course, in menu-reading order.
    public var dishesByCourse: [(course: Course, dishes: [Dish])] {
        Course.allCases.compactMap { course in
            let matching = dishes.filter { $0.course == course }
            return matching.isEmpty ? nil : (course, matching)
        }
    }
}
