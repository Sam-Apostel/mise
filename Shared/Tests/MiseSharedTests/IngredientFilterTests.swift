import XCTest
@testable import MiseShared

final class IngredientFilterTests: XCTestCase {
    // A pizzeria's board, ingredients as an Italian menu lists them.
    private let margherita = Dish(name: "Margherita", section: "Pizzas", ingredients: ["pomodoro", "fior di latte", "basilico"])
    private let ortolana = Dish(name: "Ortolana", section: "Pizzas",
                                ingredients: ["pomodoro", "mozzarella", "peperoni", "melanzane", "zucchine"])
    private let boscaiola = Dish(name: "Boscaiola", section: "Pizzas",
                                 ingredients: ["mozzarella", "funghi champignon", "salsiccia", "peperoni"])
    private let tonno = Dish(name: "Tonno e cipolla", section: "Pizzas",
                             allergens: [.fish], ingredients: ["pomodoro", "mozzarella", "tonno", "cipolla rossa"])
    private let marinara = Dish(name: "Marinara", section: "Pizzas", ingredients: ["pomodoro", "aglio", "origano"])
    private let tiramisu = Dish(name: "Tiramisù", section: "Desserts", ingredients: ["mascarpone", "uova", "caffè"])

    private var board: [Dish] { [margherita, ortolana, boscaiola, tonno, marinara, tiramisu] }

    func testLexiconMapsMenuWordsToStandardNames() {
        XCTAssertEqual(IngredientLexicon.key(for: "Funghi champignon"), IngredientKey(name: "mushroom", family: .mushroom))
        XCTAssertEqual(IngredientLexicon.key(for: "peperoni").name, "bell pepper")
        XCTAssertEqual(IngredientLexicon.key(for: "pepperoni").name, "salami")
        XCTAssertEqual(IngredientLexicon.key(for: "fior di latte").name, "mozzarella")
        XCTAssertEqual(IngredientLexicon.key(for: "mozzarella di bufala campana").name, "mozzarella")
        XCTAssertEqual(IngredientLexicon.key(for: "Mushrooms").name, "mushroom")
        XCTAssertEqual(IngredientLexicon.key(for: "Truffled honey"), IngredientKey(name: "truffled honey", family: .other))
    }

    func testFamiliesCoverEveryMember() {
        XCTAssertTrue(boscaiola.has("mushroom"))
        XCTAssertTrue(tonno.has("seafood"))
        XCTAssertTrue(boscaiola.has("meat"))
        XCTAssertFalse(margherita.has("seafood"))
        XCTAssertTrue(margherita.has("cheese"))
        // Allergens back up the family when the ingredient is unknown.
        XCTAssertTrue(Dish(name: "Fritto", allergens: [.shellfish], ingredients: ["fritto misto"]).has("seafood"))
    }

    func testParserKeysWinOverTheLexicon() {
        let dish = Dish(name: "X", ingredients: ["champignons"], ingredientKeys: [.init(name: "oyster mushroom", family: .mushroom)])
        XCTAssertEqual(dish.keys.map(\.name), ["oyster mushroom"])
        XCTAssertTrue(dish.has("mushroom"))
    }

    func testAvoidingAFamilyCrossesItOutWithAReason() {
        let filter = DishFilter(avoidedIngredients: ["mushroom", "seafood"])
        XCTAssertEqual(filter.apply(to: board).map(\.name), ["Margherita", "Ortolana", "Marinara", "Tiramisù"])
        let verdict = Verdict.for(boscaiola, profile: nil, filter: filter)
        XCTAssertEqual(verdict.kind, .no)
        XCTAssertEqual(verdict.reason, "Has mushrooms")
    }

    func testWantedIngredientsRankAndNoteWhatIsMissing() {
        let filter = DishFilter(preferredIngredients: ["mozzarella", "bell pepper"])
        let all = Verdict.for(ortolana, profile: nil, filter: filter)
        XCTAssertEqual(all.kind, .fine)
        XCTAssertEqual(all.cause, .wanted(missing: []))
        XCTAssertEqual(all.reason, "Bell pepper and mozzarella")

        let some = Verdict.for(margherita, profile: nil, filter: filter)
        XCTAssertEqual(some.kind, .fine)
        XCTAssertEqual(some.reason, "No bell pepper")

        let none = Verdict.for(marinara, profile: nil, filter: filter)
        XCTAssertEqual(none.kind, .no)
        XCTAssertEqual(none.reason, "No bell pepper or mozzarella")
    }

    func testProfileAvoidUsesTheLexicon() {
        let sam = Profile(name: "Sam", avoids: ["mushrooms"])
        XCTAssertEqual(Verdict.for(boscaiola, profile: sam).kind, .no)
        XCTAssertEqual(Verdict.for(margherita, profile: sam).kind, .fine)
    }

    func testIndexCountsIngredientsAndFamilies() {
        let index = IngredientIndex(dishes: board)
        XCTAssertEqual(index.ingredients.first?.key.name, "tomato")
        XCTAssertEqual(index.ingredients.first { $0.key.name == "mozzarella" }?.count, 4)
        XCTAssertEqual(index.families.first { $0.family == .seafood }?.count, 1)
        XCTAssertNil(index.families.first { $0.family == .nuts })
    }

    // MARK: Sentences

    private let sections = ["Pizzas", "Calzoni", "Desserts"]

    func testTheWholeSentence() {
        let intent = FilterIntentParser.parse(
            "I only want pizzas, with mozzarella and bell pepper. No mushrooms or seafood",
            sections: sections)
        XCTAssertEqual(intent.onlySections, ["Pizzas"])
        XCTAssertEqual(intent.want, ["mozzarella", "bell pepper"])
        XCTAssertEqual(intent.avoid, ["mushroom", "seafood"])

        var filter = DishFilter()
        var hidden: Set<String> = []
        intent.apply(to: &filter, hiddenSections: &hidden, allSections: sections)
        XCTAssertEqual(hidden, ["Calzoni", "Desserts"])
        XCTAssertEqual(filter.preferredIngredients, ["mozzarella", "bell pepper"])
        XCTAssertEqual(filter.avoidedIngredients, ["mushroom", "seafood"])
    }

    func testOtherLanguagesAndPhrasings() {
        let dutch = FilterIntentParser.parse("alleen pizza met paddenstoelen, geen vis", sections: sections)
        XCTAssertEqual(dutch.onlySections, ["Pizzas"])
        XCTAssertEqual(dutch.want, ["mushroom"])
        XCTAssertEqual(dutch.avoid, ["seafood"])

        let notWant = FilterIntentParser.parse("I don't want onions or meat", sections: sections)
        XCTAssertEqual(notWant.avoid, ["onion", "meat"])
        XCTAssertTrue(notWant.want.isEmpty)

        let pizze = FilterIntentParser.parse("pizza without anchovies", sections: ["Pizze rosse", "Pizze bianche"])
        XCTAssertEqual(pizze.onlySections, ["Pizze rosse", "Pizze bianche"])
        XCTAssertEqual(pizze.avoid, ["anchovy"])

        let diet = FilterIntentParser.parse("something vegetarian, not spicy, under €12", sections: sections)
        XCTAssertEqual(diet.requiredTags, [.vegetarian])
        XCTAssertEqual(diet.maxSpice, SpiceLevel.none)
        XCTAssertEqual(diet.maxPrice, 12)
    }

    func testMenuWordsTheLexiconDoesNotKnow() {
        let intent = FilterIntentParser.parse("no stracchino", sections: sections, ingredients: ["stracchino"])
        XCTAssertEqual(intent.avoid, ["stracchino"])
    }

    func testAPlainDishNameIsNotAFilter() {
        XCTAssertTrue(FilterIntentParser.parse("margherita", sections: sections).isEmpty)
    }
}
