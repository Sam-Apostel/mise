import SwiftUI
import Observation
import MiseShared

/// Holds the live filter state for the menu browser and derives the visible dishes,
/// per-option match counts, and the "loosen one" suggestions for the empty state.
@MainActor
@Observable
final class MenuFilterModel {
    var filter = DishFilter()

    // MARK: - Toggles

    func toggleRequired(_ tag: DietaryTag) {
        if filter.requiredTags.contains(tag) {
            filter.requiredTags.remove(tag)
        } else {
            filter.requiredTags.insert(tag)
            filter.excludedTags.remove(tag)
        }
    }

    func toggleExcluded(_ tag: DietaryTag) {
        if filter.excludedTags.contains(tag) {
            filter.excludedTags.remove(tag)
        } else {
            filter.excludedTags.insert(tag)
            filter.requiredTags.remove(tag)
        }
    }

    func toggleAllergen(_ allergen: Allergen) {
        if filter.avoidAllergens.contains(allergen) {
            filter.avoidAllergens.remove(allergen)
        } else {
            filter.avoidAllergens.insert(allergen)
        }
    }

    func toggleCourse(_ course: Course) {
        if filter.courses.contains(course) {
            filter.courses.remove(course)
        } else {
            filter.courses.insert(course)
        }
    }

    func setMaxSpice(_ level: SpiceLevel?) {
        filter.maxSpice = level
    }

    func clear() {
        let search = filter.searchText
        filter = DishFilter()
        filter.searchText = search
    }

    // MARK: - Derived

    func visible(in menu: ParsedMenu) -> [Dish] {
        filter.apply(to: menu.dishes)
    }

    /// Sections of filtered dishes, grouped by course in reading order.
    func sections(for menu: ParsedMenu) -> [(course: Course, dishes: [Dish])] {
        let visible = visible(in: menu)
        return Course.allCases.compactMap { course in
            let matching = visible.filter { $0.course == course }
            return matching.isEmpty ? nil : (course, matching)
        }
    }

    // MARK: - Match-count previews (Filters screen)

    func countRequiring(_ tag: DietaryTag, in dishes: [Dish]) -> Int {
        filter.count(in: dishes) { $0.requiredTags.insert(tag); $0.excludedTags.remove(tag) }
    }

    func countAvoiding(_ allergen: Allergen, in dishes: [Dish]) -> Int {
        filter.count(in: dishes) { $0.avoidAllergens.insert(allergen) }
    }

    func countMaxSpice(_ level: SpiceLevel, in dishes: [Dish]) -> Int {
        filter.count(in: dishes) { $0.maxSpice = level }
    }

    // MARK: - Empty state ("loosen one")

    /// A single relaxation the diner could make, with how many dishes it would unlock.
    struct Suggestion: Identifiable {
        let id = UUID()
        let label: String
        let resultCount: Int
        let apply: @MainActor () -> Void
    }

    /// The active constraints ranked by how much they'd unlock if dropped — the
    /// first is "doing most of the damage".
    func loosenSuggestions(for dishes: [Dish]) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        for tag in filter.requiredTags {
            let count = filter.count(in: dishes) { $0.requiredTags.remove(tag) }
            suggestions.append(.init(label: "drop \(tag.displayName.lowercased())",
                                     resultCount: count) { [weak self] in self?.filter.requiredTags.remove(tag) })
        }
        for tag in filter.excludedTags {
            let count = filter.count(in: dishes) { $0.excludedTags.remove(tag) }
            suggestions.append(.init(label: "allow \(tag.displayName.lowercased())",
                                     resultCount: count) { [weak self] in self?.filter.excludedTags.remove(tag) })
        }
        for allergen in filter.avoidAllergens {
            let count = filter.count(in: dishes) { $0.avoidAllergens.remove(allergen) }
            suggestions.append(.init(label: "allow \(allergen.displayName.lowercased())",
                                     resultCount: count) { [weak self] in self?.filter.avoidAllergens.remove(allergen) })
        }
        if let spice = filter.maxSpice {
            let count = filter.count(in: dishes) { $0.maxSpice = nil }
            suggestions.append(.init(label: "allow spicier than \(spice.displayName.lowercased())",
                                     resultCount: count) { [weak self] in self?.filter.maxSpice = nil })
        }

        return suggestions.sorted { $0.resultCount > $1.resultCount }
    }
}
