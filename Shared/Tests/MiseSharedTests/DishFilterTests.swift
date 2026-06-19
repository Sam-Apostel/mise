import XCTest
@testable import MiseShared

final class DishFilterTests: XCTestCase {
    private let dishes: [Dish] = [
        Dish(name: "Margherita Pizza", course: .main, dietaryTags: [.vegetarian], allergens: [.gluten, .dairy], spiceLevel: .none, ingredients: ["tomato", "mozzarella", "basil"], confidence: 0.9),
        Dish(name: "Spicy Tuna Roll", course: .starter, dietaryTags: [.pescatarian, .spicy], allergens: [.fish], spiceLevel: .hot, ingredients: ["tuna", "rice", "chili"], confidence: 0.8),
        Dish(name: "Beef Burger", price: 14, currency: "EUR", course: .main, dietaryTags: [.containsPork], allergens: [.gluten], spiceLevel: .mild, ingredients: ["beef", "bacon"], confidence: 0.7),
    ]

    func testAvoidAllergenExcludesGluten() {
        let filter = DishFilter(avoidAllergens: [.gluten])
        XCTAssertEqual(filter.apply(to: dishes).map(\.name), ["Spicy Tuna Roll"])
    }

    func testMaxSpiceCeiling() {
        let filter = DishFilter(maxSpice: .mild)
        let names = filter.apply(to: dishes).map(\.name)
        XCTAssertTrue(names.contains("Margherita Pizza"))
        XCTAssertTrue(names.contains("Beef Burger"))
        XCTAssertFalse(names.contains("Spicy Tuna Roll"))
    }

    func testCountPreviewForAddingTag() {
        let filter = DishFilter()
        let count = filter.count(in: dishes) { $0.requiredTags.insert(.vegetarian) }
        XCTAssertEqual(count, 1)
    }

    func testRequiredTagFiltersToVegetarian() {
        let filter = DishFilter(requiredTags: [.vegetarian])
        XCTAssertEqual(filter.apply(to: dishes).map(\.name), ["Margherita Pizza"])
    }

    func testExcludedTagRemovesPork() {
        let filter = DishFilter(excludedTags: [.containsPork])
        XCTAssertFalse(filter.apply(to: dishes).contains { $0.name == "Beef Burger" })
    }

    func testSearchMatchesIngredients() {
        let filter = DishFilter(searchText: "chili")
        XCTAssertEqual(filter.apply(to: dishes).map(\.name), ["Spicy Tuna Roll"])
    }

    func testMaxPriceFiltersOutExpensive() {
        let filter = DishFilter(maxPrice: 10)
        XCTAssertFalse(filter.apply(to: dishes).contains { $0.name == "Beef Burger" })
    }

    func testInactiveFilterPassesEverything() {
        XCTAssertEqual(DishFilter().apply(to: dishes).count, dishes.count)
    }
}
