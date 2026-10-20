import Foundation

/// Pure filtering logic shared between app and server so behaviour stays consistent.
public struct DishFilter: Codable, Hashable, Sendable {
    /// A dish must carry *all* of these tags to pass (logical AND).
    public var requiredTags: Set<DietaryTag>
    /// A dish must carry *none* of these tags to pass.
    public var excludedTags: Set<DietaryTag>
    /// Allergens to avoid — a dish containing any of these fails.
    public var avoidAllergens: Set<Allergen>
    /// Maximum acceptable spice level (inclusive). `nil` means no spice constraint.
    public var maxSpice: SpiceLevel?
    /// Ingredients the diner wants ("mozzarella", "bell pepper"). A dish with
    /// none of them fails; one with only some passes and sorts after those with all.
    /// Standard names or families (see `Dish.has(_:)`).
    public var preferredIngredients: Set<String>
    /// Ingredients or families to avoid ("mushroom", "seafood", "coriander"):
    /// a dish containing any of these fails.
    public var avoidedIngredients: Set<String>
    /// When non-empty, only these courses pass.
    public var courses: Set<Course>
    /// Free-text query matched against name, description, and ingredients.
    public var searchText: String
    /// Maximum price (inclusive) when set.
    public var maxPrice: Decimal?

    public init(
        requiredTags: Set<DietaryTag> = [],
        excludedTags: Set<DietaryTag> = [],
        avoidAllergens: Set<Allergen> = [],
        maxSpice: SpiceLevel? = nil,
        preferredIngredients: Set<String> = [],
        avoidedIngredients: Set<String> = [],
        courses: Set<Course> = [],
        searchText: String = "",
        maxPrice: Decimal? = nil
    ) {
        self.requiredTags = requiredTags
        self.excludedTags = excludedTags
        self.avoidAllergens = avoidAllergens
        self.maxSpice = maxSpice
        self.preferredIngredients = preferredIngredients
        self.avoidedIngredients = avoidedIngredients
        self.courses = courses
        self.searchText = searchText
        self.maxPrice = maxPrice
    }

    public var isActive: Bool {
        !requiredTags.isEmpty || !excludedTags.isEmpty || !avoidAllergens.isEmpty
            || maxSpice != nil || !preferredIngredients.isEmpty || !avoidedIngredients.isEmpty
            || !courses.isEmpty || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            || maxPrice != nil
    }

    public func matches(_ dish: Dish) -> Bool {
        if !requiredTags.isSubset(of: Set(dish.dietaryTags)) { return false }
        if !excludedTags.isDisjoint(with: Set(dish.dietaryTags)) { return false }
        if !avoidAllergens.isDisjoint(with: Set(dish.allergens)) { return false }
        if let maxSpice, dish.spiceLevel > maxSpice { return false }
        if !courses.isEmpty, !courses.contains(dish.course) { return false }
        if let maxPrice, let price = dish.price, price > maxPrice { return false }

        if !preferredIngredients.isEmpty, !preferredIngredients.contains(where: dish.has) { return false }
        if avoidedIngredients.contains(where: { dish.contains(avoid: $0) }) { return false }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            let haystack = ([dish.name, dish.originalName ?? "", dish.description ?? ""] + dish.ingredients)
                .joined(separator: " ")
                .lowercased()
            if !haystack.contains(query) { return false }
        }
        return true
    }

    /// The wanted ingredients `dish` lacks, in a stable order.
    public func missingWanted(in dish: Dish) -> [String] {
        preferredIngredients.sorted().filter { !dish.has($0) }
    }

    public func apply(to dishes: [Dish]) -> [Dish] {
        dishes.filter(matches)
    }

    // MARK: - Match-count previews (for the Filters screen)

    /// How many dishes would match if `transform` were applied to this filter.
    /// Used to render the live counts next to each option ("Vegan 9").
    public func count(in dishes: [Dish], with transform: (inout DishFilter) -> Void) -> Int {
        var copy = self
        transform(&copy)
        return copy.apply(to: dishes).count
    }
}
