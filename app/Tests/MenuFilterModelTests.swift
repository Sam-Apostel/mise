import XCTest
import MiseShared
@testable import Mise

@MainActor
final class MenuFilterModelTests: XCTestCase {
    private let menu = ParsedMenu(dishes: [
        Dish(name: "Garden Salad", course: .starter, dietaryTags: [.vegan, .vegetarian]),
        Dish(name: "Ribeye Steak", course: .main, dietaryTags: []),
        Dish(name: "Cheesecake", course: .dessert, dietaryTags: [.vegetarian]),
    ])

    func testRequiredTagNarrowsSections() {
        let model = MenuFilterModel()
        model.toggleRequired(.vegan)
        let sections = model.sections(for: menu)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.dishes.map(\.name), ["Garden Salad"])
    }

    func testRequiringAndExcludingSameTagAreMutuallyExclusive() {
        let model = MenuFilterModel()
        model.toggleRequired(.vegetarian)
        model.toggleExcluded(.vegetarian)
        XCTAssertFalse(model.filter.requiredTags.contains(.vegetarian))
        XCTAssertTrue(model.filter.excludedTags.contains(.vegetarian))
    }

    func testCourseFilter() {
        let model = MenuFilterModel()
        model.toggleCourse(.dessert)
        let sections = model.sections(for: menu)
        XCTAssertEqual(sections.map(\.course), [.dessert])
    }
}
