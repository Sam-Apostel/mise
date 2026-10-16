import XCTest
@testable import MiseShared

final class VerdictTests: XCTestCase {
    private let els = Profile(name: "Els", allergens: [.peanuts, .shellfish], avoids: ["pork"],
                              maxSpice: .hot, severe: true, speech: .feminine)
    private let luc = Profile(name: "Luc", allergens: [.dairy], maxSpice: .mild, speech: .masculine)

    private let somTam = Dish(
        name: "Som Tam Thai", allergens: [.peanuts, .shellfish],
        allergenSources: [.init(allergen: .peanuts, ingredient: "peanuts"),
                          .init(allergen: .shellfish, ingredient: "dried shrimp")],
        spiceLevel: .hot)
    private let greenCurry = Dish(
        name: "Green curry, chicken",
        likelyIngredients: [.init(name: "shrimp paste", allergens: [.shellfish], question: "มีกะปิไหม")],
        spiceLevel: .hot)
    private let parmigiana = Dish(
        name: "Parmigiana", dietaryTags: [.vegetarian],
        likelyIngredients: [.init(name: "animal rennet", breaks: [.vegetarian],
                                  note: "Parmigiano uses animal rennet")])
    private let tagliatelle = Dish(name: "Tagliatelle al ragù", protein: "beef and pork")

    func testListedAllergenIsNoWithIngredientReason() {
        let v = Verdict.for(somTam, profile: els)
        XCTAssertEqual(v.kind, .no)
        XCTAssertEqual(v.reason, "Peanuts, dried shrimp")
    }

    func testLikelyAllergenIsAsk() {
        let v = Verdict.for(greenCurry, profile: els)
        XCTAssertEqual(v.kind, .ask)
        XCTAssertEqual(v.reason, "Shrimp paste? Ask.")
    }

    func testSpiceAboveCapIsNo() {
        let v = Verdict.for(greenCurry, profile: luc)
        XCTAssertEqual(v.kind, .no)
        XCTAssertEqual(v.reason, "Hot")
    }

    func testAvoidMatchesProtein() {
        let v = Verdict.for(tagliatelle, profile: els)
        XCTAssertEqual(v.kind, .no)
        XCTAssertEqual(v.reason, "Pork")
    }

    func testEveryoneSeesOnlyTheFilter() {
        XCTAssertEqual(Verdict.for(somTam, profile: nil).kind, .fine)
        let veg = DishFilter(requiredTags: [.vegetarian])
        let v = Verdict.for(tagliatelle, profile: nil, filter: veg)
        XCTAssertEqual(v.kind, .no)
        XCTAssertEqual(v.reason, "Beef and pork")
    }

    func testFilterMakesLikelyIngredientAsk() {
        let veg = DishFilter(requiredTags: [.vegetarian])
        let v = Verdict.for(parmigiana, profile: nil, filter: veg)
        XCTAssertEqual(v.kind, .ask)
        XCTAssertEqual(v.reason, "Parmigiano uses animal rennet. Ask.")
    }

    func testOldPayloadDecodesWithDefaults() throws {
        let json = #"{"name":"Soup","course":"starter","dietaryTags":[],"allergens":[],"spiceLevel":"none","ingredients":[],"isPopular":false,"confidence":0.5,"id":"7C9D1E2A-0000-4000-8000-000000000001","plate":"from_the_future"}"#
        let dish = try JSONDecoder().decode(Dish.self, from: Data(json.utf8))
        XCTAssertEqual(dish.plate, .generic)
        XCTAssertTrue(dish.likelyIngredients.isEmpty)
        XCTAssertNil(dish.menuNumber)
    }
}

final class PhraseBookTests: XCTestCase {
    func testThaiAllergyLinesMatchTheWaiterCard() throws {
        let set = try XCTUnwrap(PhraseBook.phrases(language: "th", allergens: [.peanuts, .shellfish], speech: .feminine))
        XCTAssertEqual(set.allergy, ["แพ้ถั่วลิสง กุ้ง และปู", "ไม่ใส่ถั่ว กุ้ง ปู"])
        XCTAssertEqual(set.thanks, "ขอบคุณค่ะ")
        XCTAssertEqual(set.allergyTranslation, "Allergic to peanuts, shrimp and crab. None of them, please.")
    }

    func testItalianAllergyLineIsGendered() throws {
        let set = try XCTUnwrap(PhraseBook.phrases(language: "it-IT", allergens: [.shellfish, .peanuts], speech: .feminine))
        XCTAssertEqual(set.allergy, ["Sono allergica alle arachidi e ai crostacei: gamberi, granchio."])
        let neutral = try XCTUnwrap(PhraseBook.phrases(language: "it", allergens: [.sesame]))
        XCTAssertEqual(neutral.allergy, ["Ho un'allergia al sesamo."])
    }

    func testUnknownLanguageIsNil() {
        XCTAssertNil(PhraseBook.phrases(language: "ja", allergens: [.egg]))
    }
}
