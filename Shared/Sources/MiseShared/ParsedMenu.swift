import Foundation

/// A full menu after OCR + parsing/enrichment.
public struct ParsedMenu: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var restaurantName: String?
    /// The restaurant's name in the menu's own script ("ครัวป้านิด"), when it differs.
    public var originalRestaurantName: String?
    /// Cuisine in the user's language ("Thai", "Italian").
    public var cuisine: String?
    /// Where the menu was read ("Ortigia, Siracusa"), when known.
    public var place: String?
    /// BCP-47 language code of the source menu, when detected (e.g. "th", "it").
    public var sourceLanguage: String?
    /// Default ISO 4217 currency for the menu, when detected.
    public var currency: String?
    /// Rate into the diner's home currency, for "฿95 · €2.55".
    public var exchange: ExchangeRate?
    /// When the menu was read; drives "last night" on the Recent list.
    public var scannedAt: Date?
    public var dishes: [Dish]

    public init(
        id: UUID = UUID(),
        restaurantName: String? = nil,
        originalRestaurantName: String? = nil,
        cuisine: String? = nil,
        place: String? = nil,
        sourceLanguage: String? = nil,
        currency: String? = nil,
        exchange: ExchangeRate? = nil,
        scannedAt: Date? = nil,
        dishes: [Dish] = []
    ) {
        self.id = id
        self.restaurantName = restaurantName
        self.originalRestaurantName = originalRestaurantName
        self.cuisine = cuisine
        self.place = place
        self.sourceLanguage = sourceLanguage
        self.currency = currency
        self.exchange = exchange
        self.scannedAt = scannedAt
        self.dishes = dishes
    }

    private enum CodingKeys: String, CodingKey {
        case id, restaurantName, originalRestaurantName, cuisine, place, sourceLanguage
        case currency, exchange, scannedAt, dishes
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        restaurantName = try c.decodeIfPresent(String.self, forKey: .restaurantName)
        originalRestaurantName = try c.decodeIfPresent(String.self, forKey: .originalRestaurantName)
        cuisine = try c.decodeIfPresent(String.self, forKey: .cuisine)
        place = try c.decodeIfPresent(String.self, forKey: .place)
        sourceLanguage = try c.decodeIfPresent(String.self, forKey: .sourceLanguage)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        exchange = try c.decodeIfPresent(ExchangeRate.self, forKey: .exchange)
        scannedAt = try c.decodeIfPresent(Date.self, forKey: .scannedAt)
        dishes = try c.decodeIfPresent([Dish].self, forKey: .dishes) ?? []
    }

    /// Dishes grouped by course, in menu-reading order.
    public var dishesByCourse: [(course: Course, dishes: [Dish])] {
        Course.allCases.compactMap { course in
            let matching = dishes.filter { $0.course == course }
            return matching.isEmpty ? nil : (course, matching)
        }
    }

    /// Dishes grouped by the menu's own section headings, in the order they first appear.
    public var sections: [(title: String, dishes: [Dish])] {
        var order: [String] = []
        var groups: [String: [Dish]] = [:]
        for dish in dishes {
            let title = dish.sectionTitle
            if groups[title] == nil { order.append(title) }
            groups[title, default: []].append(dish)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    /// Whether the menu is written in a script the diner probably cannot read,
    /// which is when "order by number" earns its place in the eyebrow.
    public var isNonLatinScript: Bool {
        guard let sample = originalRestaurantName ?? dishes.compactMap(\.originalName).first else { return false }
        return sample.unicodeScalars.contains { $0.value > 0x024F && $0.properties.isAlphabetic }
    }
}

/// A conversion from the menu's currency into the diner's home currency.
public struct ExchangeRate: Codable, Hashable, Sendable {
    /// ISO 4217 code of the home currency ("EUR").
    public var home: String
    /// How many units of the menu's currency buy one unit of `home` (37.6 baht per euro).
    public var perHome: Decimal
    /// When the rate was fetched; older than two days is shown as stale.
    public var fetchedAt: Date?

    public init(home: String, perHome: Decimal, fetchedAt: Date? = nil) {
        self.home = home
        self.perHome = perHome
        self.fetchedAt = fetchedAt
    }

    public func convert(_ amount: Decimal) -> Decimal {
        guard perHome > 0 else { return amount }
        return amount / perHome
    }
}
